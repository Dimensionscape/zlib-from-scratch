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
class Adler32 implements IChecksum {
	static inline final BLOCK_SIZE:UInt = 5552;
	static inline final MODULO:UInt = 65521;

	var _bytesLeftInBlock:UInt = BLOCK_SIZE;
	var _iterator:UInt = 0;
	var _s1:UInt = 1;
	var _s2:UInt = 0;

	public function reset() {
		_bytesLeftInBlock = BLOCK_SIZE;
		_s1 = 1;
		_s2 = 2;
	}

	public function feed(input:ByteArray, position:UInt, length:UInt) {
		_iterator = position;
		while (_iterator < position + length) {
			_s1 += input[_iterator];
			_s2 += _s1;
			_bytesLeftInBlock--;
			if (_bytesLeftInBlock == 0) {
				_s1 %= MODULO;
				_s2 %= MODULO;
				_bytesLeftInBlock = BLOCK_SIZE;
			}
			_iterator++;
		}
	}

	public function feedByte(byte:UInt) {
		_s1 += byte;
		_s2 += _s1;
		_bytesLeftInBlock--;
		if (_bytesLeftInBlock == 0) {
			_s1 %= MODULO;
			_s2 %= MODULO;
			_bytesLeftInBlock = BLOCK_SIZE;
		}
	}

	@:flash.property public var bytesAccumulated(get, never):UInt;

	function get_bytesAccumulated():UInt {
		return 0;
	}

	@:flash.property public var checksum(get, never):UInt;

	function get_checksum():UInt {
		return ((_s2 % MODULO) << 16) | (_s1 % MODULO);
	}

	public function new() {}
}
