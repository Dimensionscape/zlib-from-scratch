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

package org.zlibfromscratch.zlibinternal;
import openfl.errors.Error;

/** @private For internal use only. */
class HuffmanDecoder
{
	static var _reversed:UInt = 0;

	var _length_count:Array<Dynamic> = [];
	var _max_length:UInt = 0;
	var _sorted_symbols:Array<Dynamic> = [];
	var _table:Array<Dynamic> = [];

	public function new(code_lengths:Dynamic, offset:UInt = 0, length:UInt = 0)
	{
		_length_count.resize(0);
		_sorted_symbols.resize(0);

		var symbol:UInt;
		var code:UInt;
		var n:UInt;
		var len:UInt;
		var i:UInt;
		var j:UInt;
		var max_code:UInt;
		var k:UInt;

		if (offset > code_lengths.length)
		{
			throw new Error("Invalid offset in Huffman decoder construction.");
		}

		if (length == 0)
			length = code_lengths.length - offset;

		for (_tmp_ in 0...length)
		{
			symbol = _tmp_;
			len = code_lengths[symbol + offset];
			if (!_length_count[len])
			{
				_length_count[len] = 1;
			}
			else
			{
				_length_count[len] += 1;
			}
			if (len != 0)
			{
				_sorted_symbols.push({symbol: symbol, length: len});
			}
		}
		// old as3 sort solution
		// _sorted_symbols.sortOn(["length", "symbol"], [Array.NUMERIC, Array.NUMERIC]);

		_sorted_symbols.sort(function(a:Dynamic, b:Dynamic):Dynamic
		{
			if (a.length == b.length)
			{
				return b.symbol - a.symbol;
			}
			return a.length > b.length ? 1 : -1;
		});

		_max_length = _length_count.length - 1;
		max_code = (1 << _max_length) - 1;

		// build the array out in order so that it's properly packed.
		// this is an AS3-specific optimization.
		_table.resize(0);
		trace("resize");
		n = 0;
		code = 0;
		len = 1;
		trace(_length_count.length);
		//for (i in len..._length_count.length){
			//k = (1 << i);
			//if (_length_count[len]==null)
					////_length_count[len] = 0; // turns undefined into 0.
				////for (i = 0; i < _length_count[len]; i++)
				////{
					////for (j = reverseBits(code, len); j <= max_code; j += k)
					////{
						////_table[j] = [_sorted_symbols[n].symbol, len];
					////}
					////n++;
					////code++;
				////}
				////code <<= 1;
			//
		//}
		
		//for (len = 1; len < _length_count.length; len++)
			//{
				//k = (1 << len);
				//if (!_length_count[len])
					//_length_count[len] = 0; // turns undefined into 0.
				//for (i = 0; i < _length_count[len]; i++)
				//{
					//for (j = reverseBits(code, len); j <= max_code; j += k)
					//{
						//_table[j] = [_sorted_symbols[n].symbol, len];
					//}
					//n++;
					//code++;
				//}
				//code <<= 1;
			//}
			
		while (len < (_length_count.length:UInt))
		{
			k = (1 << len);
			if (_length_count[len] == null)
				_length_count[len] = 0; // turns undefined into 0.
			i = 0;
			while (i < _length_count[len])
			{
				j = reverseBits(code, len);
				while (j <= max_code)
				{
					_table[j] = [_sorted_symbols[n].symbol, len];
					j += k;
				}
				n++;
				code++;
				i++;
			}
			code <<= 1;
			len++;
		}

		DisposeUtil.genericDispose(_sorted_symbols);
		DisposeUtil.genericDispose(_length_count);
	}

	public function dispose()
	{
		DisposeUtil.genericDispose(_table);
	}

	static function reverseBits(data:UInt, numBits:UInt):UInt
	{
		_reversed = 0;
		while (numBits != 0)
		{
			_reversed <<= 1;
			_reversed |= data & 1;
			data >>= 1;
			numBits--;
		}
		return _reversed;
	}

	public function bitsUsed(code:UInt):UInt
	{
		return _table[code][1];
	}

	public function decode(code:UInt):UInt
	{
		return _table[code][0];
	}

	@:flash.property public var maxLength(get, never):UInt;

	function get_maxLength():UInt
	{
		return _max_length;
	}
}
