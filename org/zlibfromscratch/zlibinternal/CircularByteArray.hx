// KABAM CHANGE BEGIN - Allow output stream to be emptied between feeds. -bmazza 6/10/13
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
import helper.UIntHelper;
import openfl.errors.Error;

/** @private For internal use only. */
class CircularByteArray
{
	var _ar:ByteArray = new ByteArray();
	var _beginIdx:UInt = 0;
	var _idx:UInt = 0;
	var _lengthCurrent:UInt = 0;
	var _lengthMax:UInt = 0;
	var _pos0:Int = 0;
	var _tempByteArray:ByteArray = new ByteArray();
	var _toEnd:UInt = 0;
	var _toWrite:UInt = 0;

	public function reset(lengthMax:UInt)
	{
		_ar.clear();
		_ar.length = lengthMax;
		_beginIdx = 0;
		_lengthMax = lengthMax;
		_lengthCurrent = 0;
	}

	public function appendByte(val:UInt)
	{
		if (_lengthMax == 0)
			throw new Error("maximum length is 0");

		val &= 0xFF;

		if (_lengthCurrent == _lengthMax)
		{
			if (_beginIdx < _lengthCurrent - 1)
			{
				_idx = _beginIdx++;
			}
			else
			{
				_idx = _beginIdx;
				_beginIdx = 0;
			}
		}
		else
		{
			_idx = _lengthCurrent++;
		}

		_ar.position = _idx;
		_ar.writeByte(val);
	}

	public function appendBytes(byteArray:ByteArray, pos:UInt = 0, ?count:UInt)
	{
		#if (js || neko)
		if (count == null)
		{
		#else
		if (count == 0)
		{
		#end
			count = UIntHelper.literalToUInt(4294967295);		
		}

		if (pos >= byteArray.length)
			return;
		if (byteArray.length - pos < count)
			count = byteArray.length - pos;
		if (count == 0)
			return;

		if (_lengthMax == 0)
			throw new Error("maximum length is 0");

		while (true)
		{
			_idx = (_lengthCurrent == _lengthMax) ? _beginIdx : _lengthCurrent;
			_ar.position = _idx;

			_toEnd = _lengthMax - _idx;
			if (_toEnd >= count)
			{
				_ar.writeBytes(byteArray, pos, count);
				if (_lengthMax - _lengthCurrent >= count)
				{
					_lengthCurrent += count;
				}
				else
				{
					_beginIdx = (_toEnd > count) ? _beginIdx + count : 0;
					_lengthCurrent = _lengthMax;
				}
				break;
			}
			else
			{
				_ar.writeBytes(byteArray, pos, _toEnd);
				pos += _toEnd;
				count -= _toEnd;
				_beginIdx = 0;
				_lengthCurrent = (_lengthMax - _lengthCurrent >= _toEnd) ? _lengthCurrent + _toEnd : _lengthMax;
			}
		}
	}

	public function at(idx:UInt):UInt
	{
		if (idx >= _lengthCurrent)
			throw new Error("buffer overflow");

		_toEnd = _lengthCurrent - _beginIdx;
		_idx = (_toEnd > idx) ? _beginIdx + idx : idx - _toEnd;
		return _ar[_idx];
	}

	public function getBytes(pos:UInt = 0, ?count:UInt):ByteArray
	{
		#if (js || neko)
		if (count == null)
		{
		#else
		if (count == 0)
		{
		#end
			count = UIntHelper.literalToUInt(4294967295);		
		}
		
		if (pos >= _lengthCurrent)
			throw new Error("buffer overflow");
		if (count > _lengthCurrent - pos)
			count = _lengthCurrent - pos;

		_tempByteArray.clear();
		_tempByteArray.length = count;

		_toEnd = _lengthCurrent - _beginIdx;
		if (pos < _toEnd)
		{
			_toWrite = (_toEnd - pos > count) ? count : _toEnd - pos;
			_tempByteArray.writeBytes(_ar, _beginIdx + pos, _toWrite);
			count -= _toWrite;
			_pos0 = 0;
		}
		else {
			_pos0 = pos - _toEnd;
		}

		if (count > 0)
		{
			_tempByteArray.writeBytes(_ar, _pos0, count);
		}

		return _tempByteArray;
	}

	@:flash.property public var length(get, never):UInt;

	function get_length():UInt
	{
		return _lengthCurrent;
	}

	public function new() {}
}

// KABAM CHANGE END
