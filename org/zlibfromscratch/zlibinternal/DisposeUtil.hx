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

/** @private For internal use only. */
class DisposeUtil {
	static var _iterator:Int = 0;
	static var _k:String;

	public static function genericDispose(x:Dynamic) {
		if (Std.is(x, Array)) {
			_iterator = Std.int(x.length - 1);
			while (_iterator >= 0) {
				genericDispose(x[_iterator]);
				_iterator--;
			}
			cast(x, Array<Dynamic>).resize(0);
		} else if (Std.is(x, String)) {
			// do nothing, just don't treat it as an Object.
		} else if (x != null) {
			var fields:Array<String> = Reflect.fields(x);
			 for (_k in fields)
			 {
			 genericDispose(Reflect.field(x, _k));
			Reflect.deleteField(x, _k);
			 }
		}
	}
}
