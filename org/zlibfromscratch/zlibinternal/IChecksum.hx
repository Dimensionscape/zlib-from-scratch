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
interface IChecksum {
	function feed(input:ByteArray, position:UInt, length:UInt):Void;
	function feedByte(byte:UInt):Void;
	@:flash.property var checksum(get, never):UInt;
	@:flash.property var bytesAccumulated(get, never):UInt;
}
