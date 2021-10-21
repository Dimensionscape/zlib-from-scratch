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

import flash.utils.ByteArray;

/** @private For internal use only. */
class CRC32 implements IChecksum {
	static var _table:Array<Dynamic>;

	var _acc:UInt = 0;
	var _bytes:UInt = 0;
	var _iterator:UInt = 0;
	var _x:UInt = 0;

	public function new() {
		if (_table == null) {
			var c:UInt, n:UInt, k:UInt;
			_table = [];
			for (_tmp_ in 0...256) {
				n = _tmp_;
				c = n;
				for (_tmp_ in 0...8) {
					k = _tmp_;
					if ((c & 1) != 0) {
						c = 0xedb88320 ^ ((c >> 1) & 0x7fffffff);
					} else {
						c = (c >> 1) & 0x7fffffff;
					}
				}
				_table[n] = c;
			}
		}
	}

	public function reset() {
		_acc = ~0;
		_bytes = 0;
	}

	public function feed(input:ByteArray, position:UInt, length:UInt) {
		_iterator = position;
		while (_iterator < position + length) {
			_x = (_acc ^ input[_iterator]) & 0xff;
			_acc = _table[_x] ^ ((_acc >> 8) & 0x00ffffff);
			_iterator++;
		}
		_bytes += length;
	}

	public function feedByte(byte:UInt) {
		_iterator = (_acc ^ byte) & 0xff;
		_acc = _table[_iterator] ^ ((_acc >> 8) & 0x00ffffff);
		_bytes++;
	}

	@:flash.property public var bytesAccumulated(get, never):UInt;

	function get_bytesAccumulated():UInt {
		return _bytes;
	}

	@:flash.property public var checksum(get, never):UInt;

	function get_checksum():UInt {
		return ~_acc;
	}
}
