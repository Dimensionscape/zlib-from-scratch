/*
 * This file is a part of ZlibFromScratch,
 * an open-source ActionScript decompression library.
 * Copyright (C) 2011 - Joey Parrish
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 * If not, see <http://www.gnu.org/licenses/>.
 */

package org.zlibfromscratch;

import openfl.utils.ByteArray;
import org.zlibfromscratch.zlibinternal.Adler32;
import org.zlibfromscratch.zlibinternal.CRC32;
import org.zlibfromscratch.zlibinternal.CircularByteArray;
import org.zlibfromscratch.zlibinternal.DisposeUtil;
import org.zlibfromscratch.zlibinternal.HuffmanDecoder;
import org.zlibfromscratch.zlibinternal.IChecksum;

/**
 * The ZlibDecoder class is a decompressor that supports both zlib and
 * gzip formats.
 *
 * <p>Advantages over <code>ByteArray.uncompress()</code>:</p>
 *
 * <p>
 *   <ol>
 *     <li>Compressed data does not need to be present all at once.
 *         It can be fed in a little at a time as it becomes available,
 *         for example, from a <code>Socket</code>.
 *         By contrast, <code>ByteArray.uncompress()</code> would throw
 *         an error if the data were incomplete.</li>
 *     <li>Output is generated as the corresponding input is fed in.
 *         Output can be streamed.</li>
 *     <li>If the input buffer has extra data, the excess is not lost.
 *         This allows, for example, multiple zlib-formatted compressed
 *         messages to be concatenated without size information.
 *         By contrast, <code>ByteArray.uncompress()</code> would discard
 *         any data beyond the first message.</li>
 *     <li>Gzip format is supported directly even when targeting Flash 9.
 *         By contrast, <code>ByteArray.uncompress()</code> requires
 *         Flash 10 or AIR, and further requires that the caller first
 *         parse and remove the gzip metadata.</li>
 *     <li>The compression format is automatically detected.</li>
 *   </ol>
 * </p>
 *
 * @example The following is a typical usage pattern:
 *
 * <listing version="3.0">
 *
 * var input:ByteArray = new ByteArray;
 * var output:ByteArray = new ByteArray;
 * var z:ZlibDecoder = new ZlibDecoder;
 *
 * // When data becomes available in input:
 *
 * var bytesRead:uint = z.feed(input, output);
 * input = ZlibUtil.removeBeginning(input, bytesRead); // remove consumed data
 * if (z.lastError == ZlibDecoderError.NeedMoreData) {
 *   // Wait for more data in input.
 * } else if (z.lastError == ZlibDecoderError.NoError) {
 *   // Decoding is done.
 *   // The uncompressed message is in the output ByteArray.
 *   // Any excess data that was not a part of the
 *   // compressed message is in the input ByteArray.
 * } else {
 *   // An error occurred while processing the input data.
 * }
 * </listing>
 */
class ZlibDecoder
{
	// Embedded lookup tables for length and distance codes, to quickly find the
	// number of extra bits and base values.
	static var _lcodes_extra_bits_class:Class<Dynamic> = Lcodes_Extra_Bits_Class;
	static var _lcodes_extra_bits:ByteArray = Type.createInstance(_lcodes_extra_bits_class, []);

	static var _lcodes_base_values_class:Class<Dynamic> = Lcodes_Base_Values_Class;
	static var _lcodes_base_values:ByteArray = Type.createInstance(_lcodes_base_values_class, []);

	static var _dcodes_extra_bits_class:Class<Dynamic> = Dcodes_Extra_Bits_Class;
	static var _dcodes_extra_bits:ByteArray = Type.createInstance(_dcodes_extra_bits_class, []);

	static var _dcodes_base_values_class:Class<Dynamic> = Dcodes_Base_Values_Class;
	static var _dcodes_base_values:ByteArray = Type.createInstance(_dcodes_base_values_class, []);

	// Embedded lookup table for unmixing the code code lengths. (not a typo)
	static var _deflate_length_unmix_class:Class<Dynamic> = Deflate_Length_Unmix_Class;
	static var _deflate_length_unmix:ByteArray = Type.createInstance(_deflate_length_unmix_class, []);

	// Embedded code length values for initializing the static Huffman tables.
	static var _deflate_fixed_lengths_class:Class<Dynamic>= Deflate_Fixed_Lengths_Class;
	static var _deflate_fixed_lengths:ByteArray = Type.createInstance(_deflate_fixed_lengths_class, []);

	static inline final STATE_HEADER:UInt = 0;
	static inline final STATE_BODY:UInt = 1;
	static inline final STATE_TRAILER:UInt = 2;
	static inline final STATE_DONE:UInt = 3;
	static inline final STATE_GZIP_EXTRA_HEADERS:UInt = 4;

	static inline final BLOCK_TYPE_UNCOMPRESSED:UInt = 0;
	static inline final BLOCK_TYPE_FIXED:UInt = 1;
	static inline final BLOCK_TYPE_DYNAMIC:UInt = 2;
	static inline final BLOCK_TYPE_NONE:UInt = 3;

	static inline final BLOCK_STATE_NEED_LEN:UInt = 0;
	static inline final BLOCK_STATE_COPYING:UInt = 1;

	static inline final BLOCK_STATE_NUM_CODES:UInt = 2;
	static inline final BLOCK_STATE_GET_CODE_CODES:UInt = 3;
	static inline final BLOCK_STATE_GET_CODES:UInt = 4;
	static inline final BLOCK_STATE_HUFFMAN_LCODE:UInt = 5;
	static inline final BLOCK_STATE_HUFFMAN_DCODE:UInt = 6;

	var _adler32:Adler32;
	var _crc32:CRC32;

	// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13
	var _has_header_and_trailer:Bool = false;
	// KABAM CHANGE END
	var _main_state:UInt = 0;
	var _lastError:UInt = 0;

	var _header_pos:UInt = 0;
	var _header_cmf:UInt = 0;
	var _header_flg:UInt = 0;
	var _header_gzip:Bool = false;
	var _extra_header_bytes_left:Int = 0;
	var _header_tmp:UInt = 0;

	var _body_bits:UInt = 0;
	var _num_body_bits:UInt = 0;
	var _block_type:UInt = 0;
	var _final_block:Bool = false;
	var _block_state:UInt = 0;

	var _uncompressed_bytes_left:UInt = 0;
	var _uncompressed_tmp:UInt = 0;

	var _huffman_num_lcodes:UInt = 0;
	var _huffman_num_dcodes:UInt = 0;
	var _huffman_num_code_codes:UInt = 0;
	var _huffman_repeat_length:UInt = 0;
	var _huffman_tmp_pos:UInt = 0;
	var _huffman_tmp_lengths:Array<Dynamic>;
	var _huffman_table_0:HuffmanDecoder;
	var _huffman_table_1:HuffmanDecoder;
	var _huffman_table_2:HuffmanDecoder;
	var _huffman_table_fixed:HuffmanDecoder;

	var _trailer_pos:UInt = 0;
	var _trailer_checksum_tmp:UInt = 0;
	var _trailer_size_tmp:UInt = 0;

	// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
	var _dictionary:CircularByteArray = new CircularByteArray();

	// KABAM CHANGE END
	var _verifyChecksum:Bool = false;
	var _checksum:IChecksum;

	/**
	 * Reset the decoder's internal state.
	 * After calling <code>reset()</code>, the decoder is in a
	 * pristine state, equivalent to a newly constructed object.
	 * Must be called between reading one compressed message
	 * and beginning to read another.
	 *
	 * @param verifyChecksum
	 *   If <code>true</code>, verify the checksum of the uncompressed
	 *   data after decompression is complete.
	 *   If <code>false</code>, skip the checksum calculation and
	 *   verification, which may improve decompression speed.
	 */
	// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13

	public function new()
	{
		trace(_lcodes_extra_bits.length);
	}

	public function reset(verifyChecksum:Bool = false, includesZlibHeaderAndTrailer:Bool = true) // KABAM CHANGE END
	{
		// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13
		if (!includesZlibHeaderAndTrailer)
			verifyChecksum = false;
		// KABAM CHANGE END

		// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
		// Dispose everything but the dictionary.
		_dictionary.reset(32768);
		dispose();

		// KABAM CHANGE END
		// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13
		_has_header_and_trailer = includesZlibHeaderAndTrailer;
		_main_state = _has_header_and_trailer ? STATE_HEADER : STATE_BODY;
		// KABAM CHANGE END
		_lastError = ZlibDecoderError.NEED_MORE_DATA;
		_header_pos = 0;
		// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13
		if (!_has_header_and_trailer)
		{
			_header_cmf = (7 << 4) | 8;
			_header_flg = 1; // TODO: This may not be correct, but it works...
			_header_gzip = false;
		}
		// KABAM CHANGE END
		_body_bits = 0;
		_num_body_bits = 0;
		_block_type = BLOCK_TYPE_NONE;
		_trailer_pos = 0;
		_verifyChecksum = verifyChecksum;
		_checksum = null;
		_huffman_table_0 = null;
		_huffman_table_1 = null;
		_huffman_table_2 = null;
		_huffman_table_fixed = null;
		_huffman_tmp_lengths = null;
	}

	/**
	 * Wipe the decoder's internal state to reclaim memory.
	 * Call <code>dispose()</code> when the object is no longer needed.
	 */
	public function dispose()
	{
		_checksum = null;
		if (_huffman_table_0 != null)
			_huffman_table_0.dispose();
		_huffman_table_0 = null;
		if (_huffman_table_1 != null)
			_huffman_table_1.dispose();
		_huffman_table_1 = null;
		if (_huffman_table_2 != null)
			_huffman_table_2.dispose();
		_huffman_table_2 = null;
		if (_huffman_table_fixed != null)
			_huffman_table_fixed.dispose();
		_huffman_table_fixed = null;
		DisposeUtil.genericDispose(_huffman_tmp_lengths);
		_huffman_tmp_lengths = null;
	}

	/**
	 * Feed compressed input into the decoder and receive uncompressed
	 * output back.
	 *
	 * @param input
	 *   The compressed input data.  Data is read from the
	 *   <code>ByteArray</code> starting at position 0.
	 * @param output
	 *   The uncompressed output data.  Data is written to the
	 *   <code>ByteArray</code>'s current position.  The same
	 *   <code>output</code> object must be provided to each call to
	 *   <code>feed()</code> until <code>reset()</code> is called to
	 *   begin a new message.
	 *
	 * @return The number of bytes of input used.
	 *   Always check <code>lastError</code> for status information.
	 *
	 * @see #lastError
	 * @see ZlibDecoderError
	 */
	public function feed(input:ByteArray, output:ByteArray):UInt
	{
		if (_lastError != ZlibDecoderError.NEED_MORE_DATA)
		{
			return 0;
		}
		if (input.length == 0)
		{
			return 0;
		}

		input.position = 0;
		var previousPosition:UInt;
		final more = ZlibDecoderError.NEED_MORE_DATA;

		do {
			previousPosition = input.position;

			switch (_main_state)
			{
				case STATE_HEADER:
					readHeader(input);

				case STATE_GZIP_EXTRA_HEADERS:
					readGzipExtraHeaders(input);

				case STATE_BODY:
					readBody(input, output);

				case STATE_TRAILER:
					readTrailer(input);

				default:
					trace("Invalid state: " + _main_state);
					_lastError = ZlibDecoderError.INTERNAL_ERROR;
			}
		}
		while (input.position != previousPosition && input.bytesAvailable != 0 && _main_state != STATE_DONE && _lastError == more);

		if (_lastError == more)
		{
			if (input.position == 0)
			{
				trace("Internal error: no data consumed, no error set!");
				_lastError = ZlibDecoderError.INTERNAL_ERROR;
			}
			else if (input.bytesAvailable != 0)
			{
				trace("Internal error: not all input data consumed!");
				_lastError = ZlibDecoderError.INTERNAL_ERROR;
			}
		}
		return input.position;
	}

	/**
	 * The error code from the last call to <code>feed()</code>.
	 * The value is a constant from the <code>ZlibDecoderError</code>
	 * class.
	 *
	 * @see ZlibDecoderError
	 * @see #feed()
	 */
	@:flash.property public var lastError(get, never):UInt;

	function get_lastError():UInt
	{
		return _lastError;
	}

	function readHeader(input:ByteArray)
	{
		if (_header_pos == 0 && input.bytesAvailable != 0)
		{
			_header_cmf = input[input.position++];
			_header_pos++;
		}
		if (_header_pos == 1 && input.bytesAvailable != 0)
		{
			_header_flg = input[input.position++];
			if (_header_cmf == 0x1f && _header_flg == 0x8b)
			{
				_header_gzip = true;
				if (_verifyChecksum)
				{
					if (_crc32 == null)
						_crc32 = new CRC32();
					_crc32.reset();
					_checksum = _crc32;
				}
				_header_pos++;
			}
			else
			{
				_header_gzip = false;
				if (_verifyChecksum)
				{
					if (_adler32 == null)
						_adler32 = new Adler32();
					_adler32.reset();
					_checksum = _adler32;
				}
				if (checkHeader())
				{
					_main_state++;
				}
				return;
			}
		}
		if (_header_pos == 2 && input.bytesAvailable != 0)
		{
			_header_cmf = input[input.position++];
			_header_pos++;
		}
		if (_header_pos == 3 && input.bytesAvailable != 0)
		{
			_header_flg = input[input.position++];
			if (checkHeader())
			{
				_main_state = STATE_GZIP_EXTRA_HEADERS;
				_header_pos = 0;
				_extra_header_bytes_left = 6;
			}
		}
	}

	function readGzipExtraHeaders(input:ByteArray)
	{
		while (true)
		{
			if (_extra_header_bytes_left > 0)
			{
				if (input.bytesAvailable < (_extra_header_bytes_left:UInt))
				{
					// skip as much as we can.
					input.position += input.bytesAvailable;
					_extra_header_bytes_left -= input.bytesAvailable;
					return;
				}
				// skip the rest of these bytes.
				input.position += _extra_header_bytes_left;
				_extra_header_bytes_left = 0;
			}
			else if (_extra_header_bytes_left < 0)
			{
				// seek a zero byte.
				while (input.bytesAvailable != 0)
				{
					if (input[input.position] == 0)
					{
						break;
					}
					input.position++;
				}
				if (input[input.position] != 0)
				{
					return;
				}
				input.position++;
				_extra_header_bytes_left = 0;
			}

			if (_header_pos == 0)
			{
				if ((_header_flg & 4) != 0)
				{
					if (input.bytesAvailable == 0)
						return;
					_header_tmp = input[input.position++];
				}
				_header_pos++;
			}
			if (_header_pos == 1)
			{
				if ((_header_flg & 4) != 0)
				{
					if (input.bytesAvailable == 0)
						return;
					_extra_header_bytes_left = (_header_tmp << 8) | input[input.position++];
					_header_pos++;
					continue;
				}
				else
				{
					_header_pos++;
				}
			}
			if (_header_pos == 2)
			{
				_header_pos++;
				if ((_header_flg & 8) != 0)
				{
					_extra_header_bytes_left = -1;
					continue;
				}
			}
			if (_header_pos == 3)
			{
				_header_pos++;
				if ((_header_flg & 16) != 0)
				{
					_extra_header_bytes_left = -1;
					continue;
				}
			}
			if (_header_pos == 4)
			{
				_header_pos++;
				if ((_header_flg & 2) != 0)
				{
					_extra_header_bytes_left = 2;
					continue;
				}
			}
			if (_header_pos == 5)
			{
				_main_state = STATE_BODY;
				return;
			}
		}
	}

	function checkHeader():Bool
	{
		if (_header_gzip == false)
		{
			var check:UInt = (_header_cmf << 8) | _header_flg;
			if ((check % 31) != 0)
			{
				// The FCHECK value must be such that CMF and FLG, when viewed as
				// a 16-bit unsigned integer stored in MSB order (CMF*256 + FLG),
				// is a multiple of 31.
				_lastError = ZlibDecoderError.INVALID_HEADER;
				return false;
			}
			if ((_header_cmf & 0xf) != 8)
			{
				// This identifies the compression method used in the file. CM = 8
				// denotes the "deflate" compression method with a window size up
				// to 32K.
				_lastError = ZlibDecoderError.UNSUPPORTED_FEATURES;
				return false;
			}
			if (((_header_cmf >> 4) & 15) > 7)
			{
				// For CM = 8, CINFO is the base-2 logarithm of the LZ77 window
				// size, minus eight (CINFO=7 indicates a 32K window size). Values
				// of CINFO above 7 are not allowed in this version of the
				// specification.
				_lastError = ZlibDecoderError.INVALID_HEADER;
				return false;
			}
			if ((_header_flg & 0x20) != 0)
			{
				// bit  5       FDICT   (preset dictionary)
				_lastError = ZlibDecoderError.UNSUPPORTED_FEATURES;
				return false;
			}
			return true;
		}
		else {
			if (_header_cmf < 8)
			{
				// CM = 0-7 are reserved.
				_lastError = ZlibDecoderError.INVALID_HEADER;
				return false;
			}
			if ((_header_flg & 0xe0) != 0)
			{
				// bit 5   reserved
				// bit 6   reserved
				// bit 7   reserved
				_lastError = ZlibDecoderError.INVALID_HEADER;
				return false;
			}
			if (_header_cmf != 8)
			{
				// CM = 8 denotes the "deflate" compression method,
				// which is the one customarily used by gzip
				_lastError = ZlibDecoderError.UNSUPPORTED_FEATURES;
				return false;
			}
			return true;
		}
	}

	// You may not gather more than 25 bits at a time.
	// These restrictions are not enforced, but must be observed by the caller.
	function gatherBits(input:ByteArray, numBits:UInt):Bool
	{
		while (_num_body_bits < numBits && input.bytesAvailable != 0)
		{
			_body_bits |= input[input.position++] << _num_body_bits;
			_num_body_bits += 8;
		}
		return (_num_body_bits >= numBits);
	}

	// You must first gatherBits to make sure you have enough bits in store.
	// These restrictions are not enforced, but must be observed by the caller.
	function eatBits(numBits:UInt):UInt
	{
		var data:UInt = _body_bits & ((1 << numBits) - 1);
		_num_body_bits -= numBits;
		_body_bits >>= numBits;
		return data;
	}

	// You must first gatherBits to make sure you have enough bits in store.
	// These restrictions are not enforced, but must be observed by the caller.
	function peekBits(numBits:UInt, offset:UInt = 0):UInt
	{
		return (_body_bits >> offset) & ((1 << numBits) - 1);
	}

	function readBody(input:ByteArray, output:ByteArray)
	{
		if (_block_type == BLOCK_TYPE_NONE)
		{
			if (!gatherBits(input, 3))
				return;
			_final_block = eatBits(1) != 0;
			_block_type = eatBits(2);
			switch (_block_type)
			{
				case BLOCK_TYPE_UNCOMPRESSED:
					_num_body_bits = 0;
					_body_bits = 0;
					_block_state = BLOCK_STATE_NEED_LEN;
					_uncompressed_bytes_left = 4;

				case BLOCK_TYPE_FIXED:
					if (_huffman_table_fixed == null)
						_huffman_table_fixed = new HuffmanDecoder(_deflate_fixed_lengths);
					_block_state = BLOCK_STATE_HUFFMAN_LCODE;

				case BLOCK_TYPE_DYNAMIC:
					_block_state = BLOCK_STATE_NUM_CODES;
			}
		}

		switch (_block_type)
		{
			case BLOCK_TYPE_UNCOMPRESSED:
				readUncompressedBlock(input, output);

			case BLOCK_TYPE_FIXED:
				readFixedBlock(input, output);

			case BLOCK_TYPE_DYNAMIC:
				readDynamicBlock(input, output);

			default:
				trace("Invalid block type: " + _block_type);
				_lastError = ZlibDecoderError.INVALID_DATA;
		}

		if (_block_type == BLOCK_TYPE_NONE && _final_block)
		{
			// KABAM CHANGE BEGIN - Allow headerless streams. -bmazza 6/10/13
			_main_state = _has_header_and_trailer ? STATE_TRAILER : STATE_DONE;
			// KABAM CHANGE END
			// put back any extra whole bytes we may have read in as bits.
			input.position -= (_num_body_bits >> 3);
			_num_body_bits = 0;
			_body_bits = 0;
		}
	}

	function readUncompressedBlock(input:ByteArray, output:ByteArray)
	{
		if (_block_state == BLOCK_STATE_NEED_LEN)
		{
			if (_uncompressed_bytes_left == 4 && input.bytesAvailable != 0)
			{
				_uncompressed_tmp = input[input.position++] << 16;
				_uncompressed_bytes_left--;
			}
			if (_uncompressed_bytes_left == 3 && input.bytesAvailable != 0)
			{
				_uncompressed_tmp |= input[input.position++] << 24;
				_uncompressed_bytes_left--;
			}
			if (_uncompressed_bytes_left == 2 && input.bytesAvailable != 0)
			{
				_uncompressed_tmp |= input[input.position++];
				_uncompressed_bytes_left--;
			}
			if (_uncompressed_bytes_left == 1 && input.bytesAvailable != 0)
			{
				_uncompressed_tmp |= input[input.position++] << 8;
				_uncompressed_bytes_left--;

				_uncompressed_bytes_left = (_uncompressed_tmp >> 16) & 0xffff;
				var check:UInt = (~_uncompressed_tmp) & 0xffff; // should be 1's complement of _uncompressed_bytes_left
				if (_uncompressed_bytes_left != check)
				{
					trace("Invalid uncompressed block header.", check, _uncompressed_bytes_left, _uncompressed_tmp);
					_lastError = ZlibDecoderError.INVALID_DATA;
					return;
				}
				_block_state = BLOCK_STATE_COPYING;
			}
		}
		if (_block_state == BLOCK_STATE_COPYING)
		{
			while (_uncompressed_bytes_left != 0 && input.bytesAvailable != 0)
			{
				var grab = input.bytesAvailable;
				if (grab > _uncompressed_bytes_left)
					grab = _uncompressed_bytes_left;
				output.writeBytes(input, input.position, grab);
				// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
				_dictionary.appendBytes(input, input.position, grab);
				// KABAM CHANGE END
				if (_checksum != null)
					_checksum.feed(input, input.position, grab);
				input.position += grab;
				_uncompressed_bytes_left -= grab;
			}
			if (_uncompressed_bytes_left == 0)
			{
				_block_type = BLOCK_TYPE_NONE;
			}
		}
	}

	function bitsIntoTable(input:ByteArray, table:HuffmanDecoder, what:String):UInt
	{
		var bitsUsed:UInt;
		var bits:UInt;

		if (gatherBits(input, table.maxLength))
		{
			bits = table.maxLength;
		}
		else {
			bits = _num_body_bits;
		}

		bitsUsed = table.bitsUsed(peekBits(bits));

		if (bitsUsed == 0 || bitsUsed > bits)
		{
			if (bits == table.maxLength)
			{
				trace("Unable to find valid " + what + ".");
				_lastError = ZlibDecoderError.INVALID_DATA;
			}
			return 0;
		}

		return bitsUsed;
	}

	function readFixedBlock(input:ByteArray, output:ByteArray)
	{
		var bits:UInt;
		var symbol:UInt;
		var length:UInt;
		var copies:UInt;
		var extraBits:UInt;
		var baseValue:UInt;
		var i:UInt;
		var distance:UInt;
		var spos:UInt;
		var available:UInt;

		while (_block_state == BLOCK_STATE_HUFFMAN_LCODE || _block_state == BLOCK_STATE_HUFFMAN_DCODE)
		{
			while (_block_state == BLOCK_STATE_HUFFMAN_LCODE)
			{
				bits = bitsIntoTable(input, _huffman_table_fixed, "lcode");
				if (bits == 0)
					return;
				symbol = _huffman_table_fixed.decode(peekBits(bits));
				if (symbol < 256)
				{
					// literal byte.
					output.writeByte(symbol);
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					_dictionary.appendByte(symbol);
					// KABAM CHANGE END
					if (_checksum != null)
						_checksum.feedByte(symbol);
					eatBits(bits);
				}
				else if (symbol == 256)
				{
					// end of block.
					eatBits(bits);
					_block_type = BLOCK_TYPE_NONE;
					return;
				}
				else if (symbol < 286)
				{
					extraBits = _lcodes_extra_bits[symbol];
					baseValue = (_lcodes_base_values[symbol << 1] << 8) | _lcodes_base_values[(symbol << 1) + 1];

					if (!gatherBits(input, bits + extraBits))
						return;
					eatBits(bits);
					_huffman_repeat_length = baseValue + eatBits(extraBits); // length of the sequence to be repeated.
					_block_state = BLOCK_STATE_HUFFMAN_DCODE;
				}
				else
				{
					trace("Invalid literal/length symbol: " + symbol);
					_lastError = ZlibDecoderError.INVALID_DATA;
					return;
				}
			}

			if (!gatherBits(input, 5))
				return;
			symbol = peekBits(5);
			// reverse the bit order of a fixed-length 5-bit number:
			symbol = ((symbol & 1) << 4) | ((symbol & 2) << 2) | (symbol & 4) | ((symbol & 8) >> 2) | ((symbol & 16) >> 4);
			if (symbol < 30)
			{
				extraBits = _dcodes_extra_bits[symbol];
				baseValue = (_dcodes_base_values[symbol << 1] << 8) | _dcodes_base_values[(symbol << 1) + 1];

				if (!gatherBits(input, 5 + extraBits))
					return;
				eatBits(5);
				distance = baseValue + eatBits(extraBits);
				// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
				spos = _dictionary.length - distance;
				// KABAM CHANGE END
				while (_huffman_repeat_length != 0)
				{
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					available = _dictionary.length - spos;
					// KABAM CHANGE END
					if (available > _huffman_repeat_length)
						available = _huffman_repeat_length;
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					output.writeBytes(_dictionary.getBytes(spos, available));
					_dictionary.appendBytes(output, output.position - available, available);
					if (_checksum != null)
						_checksum.feed(output, output.position - available, available);
					// KABAM CHANGE END
					_huffman_repeat_length -= available;
				}
				_block_state = BLOCK_STATE_HUFFMAN_LCODE;
			}
			else
			{
				trace("Invalid distance symbol: " + symbol);
				_lastError = ZlibDecoderError.INVALID_DATA;
				return;
			}
		}
	}

	function readDynamicBlock(input:ByteArray, output:ByteArray)
	{
		var bits:UInt;
		var symbol:UInt;
		var length:UInt = 0;
		var copies:UInt = 0;
		var extraBits:UInt;
		var baseValue:UInt;
		var i:UInt;
		var distance:UInt;
		var spos:UInt;
		var available:UInt;

		if (_block_state == BLOCK_STATE_NUM_CODES)
		{
			if (!gatherBits(input, 14))
				return;
			_huffman_num_lcodes = eatBits(5) + 257;
			_huffman_num_dcodes = eatBits(5) + 1;
			_huffman_num_code_codes = eatBits(4) + 4;
			_block_state = BLOCK_STATE_GET_CODE_CODES;
			DisposeUtil.genericDispose(_huffman_tmp_lengths);
			_huffman_tmp_lengths = [];
			for (_tmp_ in 0...19)
			{
				i = _tmp_;
				_huffman_tmp_lengths.push(0);
			}
			_huffman_tmp_pos = 0;
		}
		if (_block_state == BLOCK_STATE_GET_CODE_CODES)
		{
			while (_huffman_tmp_pos < _huffman_num_code_codes)
			{
				if (!gatherBits(input, 3))
					return;
				_huffman_tmp_lengths[_deflate_length_unmix[_huffman_tmp_pos]] = eatBits(3);
				_huffman_tmp_pos++;
			}
			if (_huffman_table_0 != null)
				_huffman_table_0.dispose();
			_huffman_table_0 = new HuffmanDecoder(_huffman_tmp_lengths);
			_block_state = BLOCK_STATE_GET_CODES;
			DisposeUtil.genericDispose(_huffman_tmp_lengths);
			_huffman_tmp_lengths = [];
			_huffman_tmp_pos = 0;
		}
		if (_block_state == BLOCK_STATE_GET_CODES)
		{
			while (_huffman_tmp_pos < _huffman_num_lcodes + _huffman_num_dcodes)
			{
				bits = bitsIntoTable(input, _huffman_table_0, "code code");
				if (bits == 0)
					return;
				symbol = _huffman_table_0.decode(peekBits(bits));
				if (symbol < 16)
				{
					eatBits(bits);
					length = symbol;
					copies = 1;
				}
				else if (symbol < 19)
				{
					if (symbol == 16)
					{
						if (!gatherBits(input, bits + 2))
							return;
						eatBits(bits);
						length = _huffman_tmp_lengths[_huffman_tmp_lengths.length - 1];
						copies = eatBits(2) + 3;
					}
					else if (symbol == 17)
					{
						if (!gatherBits(input, bits + 3))
							return;
						eatBits(bits);
						length = 0;
						copies = eatBits(3) + 3;
					}
					else if (symbol == 18)
					{
						if (!gatherBits(input, bits + 7))
							return;
						eatBits(bits);
						length = 0;
						copies = eatBits(7) + 11;
					}
				}
				else
				{
					trace("Invalid code symbol: " + symbol);
					_lastError = ZlibDecoderError.INVALID_DATA;
					return;
				}

				for (_tmp_ in 0...copies)
				{
					i = _tmp_;
					_huffman_tmp_lengths.push(length);
				}
				_huffman_tmp_pos += copies;
			}
			if (!_huffman_tmp_lengths[256])
			{
				trace("Invalid data, missing end of block symbol.");
				_lastError = ZlibDecoderError.INVALID_DATA;
				return;
			}
			_huffman_table_1 = new HuffmanDecoder(_huffman_tmp_lengths, 0, _huffman_num_lcodes);
			_huffman_table_2 = new HuffmanDecoder(_huffman_tmp_lengths, _huffman_num_lcodes, _huffman_num_dcodes);
			_block_state = BLOCK_STATE_HUFFMAN_LCODE;
		}
		while (_block_state == BLOCK_STATE_HUFFMAN_LCODE || _block_state == BLOCK_STATE_HUFFMAN_DCODE)
		{
			while (_block_state == BLOCK_STATE_HUFFMAN_LCODE)
			{
				bits = bitsIntoTable(input, _huffman_table_1, "lcode");
				if (bits == 0)
					return;
				symbol = _huffman_table_1.decode(peekBits(bits));
				if (symbol < 256)
				{
					// literal byte.
					output.writeByte(symbol);
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					_dictionary.appendByte(symbol);
					// KABAM CHANGE END
					if (_checksum != null)
						_checksum.feedByte(symbol);
					eatBits(bits);
				}
				else if (symbol == 256)
				{
					// end of block.
					eatBits(bits);
					_block_type = BLOCK_TYPE_NONE;
					return;
				}
				else if (symbol < 286)
				{
					extraBits = _lcodes_extra_bits[symbol];
					baseValue = (_lcodes_base_values[symbol << 1] << 8) | _lcodes_base_values[(symbol << 1) + 1];

					if (!gatherBits(input, bits + extraBits))
						return;
					eatBits(bits);
					_huffman_repeat_length = baseValue + eatBits(extraBits); // length of the sequence to be repeated.
					_block_state = BLOCK_STATE_HUFFMAN_DCODE;
				}
				else
				{
					trace("Invalid literal/length symbol: " + symbol);
					_lastError = ZlibDecoderError.INVALID_DATA;
					return;
				}
			}

			bits = bitsIntoTable(input, _huffman_table_2, "dcode");
			if (bits == 0)
				return;
			symbol = _huffman_table_2.decode(peekBits(bits));
			if (symbol < 30)
			{
				extraBits = _dcodes_extra_bits[symbol];
				baseValue = (_dcodes_base_values[symbol << 1] << 8) | _dcodes_base_values[(symbol << 1) + 1];

				if (!gatherBits(input, bits + extraBits))
					return;
				eatBits(bits);
				distance = baseValue + eatBits(extraBits);
				// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
				spos = _dictionary.length - distance;
				// KABAM CHANGE END
				while (_huffman_repeat_length != 0)
				{
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					available = _dictionary.length - spos;
					// KABAM CHANGE END
					if (available > _huffman_repeat_length)
						available = _huffman_repeat_length;
					// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
					output.writeBytes(_dictionary.getBytes(spos, available));
					_dictionary.appendBytes(output, output.position - available, available);
					if (_checksum != null)
						_checksum.feed(output, output.position - available, available);
					// KABAM CHANGE END
					_huffman_repeat_length -= available;
				}
				_block_state = BLOCK_STATE_HUFFMAN_LCODE;
			}
			else
			{
				trace("Invalid distance symbol: " + symbol);
				_lastError = ZlibDecoderError.INVALID_DATA;
				return;
			}
		}
	}

	function readTrailer(input:ByteArray)
	{
		if (_trailer_pos == 0 && input.bytesAvailable != 0)
		{
			_trailer_checksum_tmp = input[input.position++] << 24;
			_trailer_pos++;
		}
		if (_trailer_pos == 1 && input.bytesAvailable != 0)
		{
			_trailer_checksum_tmp |= input[input.position++] << 16;
			_trailer_pos++;
		}
		if (_trailer_pos == 2 && input.bytesAvailable != 0)
		{
			_trailer_checksum_tmp |= input[input.position++] << 8;
			_trailer_pos++;
		}
		if (_trailer_pos == 3 && input.bytesAvailable != 0)
		{
			_trailer_checksum_tmp |= input[input.position++];
			if (_header_gzip == false)
			{
				if (checkTrailer())
				{
					_lastError = ZlibDecoderError.NO_ERROR;
					_main_state++;
				}
			}
			else
			{
				// swap the bytes if it's a gzip header.
				// our crc32 implementation spits out in the opposite byte order.
				_trailer_checksum_tmp = (_trailer_checksum_tmp & 0xff) << 24 | (_trailer_checksum_tmp & 0xff00) << 8 | (_trailer_checksum_tmp & 0xff0000) >> 8 | (_trailer_checksum_tmp & 0xff000000) >> 24;
				_trailer_pos++;
			}
		}
		if (_trailer_pos == 4 && input.bytesAvailable != 0)
		{
			_trailer_size_tmp = input[input.position++];
			_trailer_pos++;
		}
		if (_trailer_pos == 5 && input.bytesAvailable != 0)
		{
			_trailer_size_tmp |= input[input.position++] << 8;
			_trailer_pos++;
		}
		if (_trailer_pos == 6 && input.bytesAvailable != 0)
		{
			_trailer_size_tmp |= input[input.position++] << 16;
			_trailer_pos++;
		}
		if (_trailer_pos == 7 && input.bytesAvailable != 0)
		{
			_trailer_size_tmp |= input[input.position++] << 24;
			if (checkTrailer())
			{
				_lastError = ZlibDecoderError.NO_ERROR;
				_main_state++;
			}
		}
	}

	function checkTrailer():Bool
	{
		if (_verifyChecksum)
		{
			if (_trailer_checksum_tmp != _checksum.checksum)
			{
				_lastError = ZlibDecoderError.CHECKSUM_MISMATCH;
				return false;
			}
			if (_header_gzip && _trailer_size_tmp != _checksum.bytesAccumulated)
			{
				_lastError = ZlibDecoderError.CHECKSUM_MISMATCH;
				return false;
			}
		}
		return true;
	}
}

@:file('org/zlibfromscratch/assets/lcodes.extra_bits')
class Lcodes_Extra_Bits_Class extends ByteArrayData { }

@:file('org/zlibfromscratch/assets/lcodes.base_values')
class Lcodes_Base_Values_Class extends ByteArrayData { }

@:file('org/zlibfromscratch/assets/dcodes.extra_bits')
class Dcodes_Extra_Bits_Class extends ByteArrayData { }

@:file('org/zlibfromscratch/assets/dcodes.base_values')
class Dcodes_Base_Values_Class extends ByteArrayData { }

@:file('org/zlibfromscratch/assets/deflate_length_unmix')
class Deflate_Length_Unmix_Class extends ByteArrayData { }

@:file('org/zlibfromscratch/assets/deflate_fixed_lengths')
class Deflate_Fixed_Lengths_Class extends ByteArrayData { }
