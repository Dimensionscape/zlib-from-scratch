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

/**
 * The <code>ZlibDecoderError</code> class contains error constants to
 * describe the status of a <code>ZlibDecoder</code>.
 *
 * @see ZlibDecoder#lastError
 * @see ZlibDecoder#feed()
 */
class ZlibDecoderError {
	/** No error; decompression is complete. */
	public static inline final NO_ERROR:UInt = 0;

	/** More compressed data is required. */
	public static inline final NEED_MORE_DATA:UInt = 1;

	/** The compressed data relies on features that have not been implemented. */
	public static inline final UNSUPPORTED_FEATURES:UInt = 2;

	/** The compressed data's header is invalid. */
	public static inline final INVALID_HEADER:UInt = 3;

	/** The compressed data is invalid. */
	public static inline final INVALID_DATA:UInt = 4;

	/** The checksum of the uncompressed data does not match the checksum found in the metadata. */
	public static inline final CHECKSUM_MISMATCH:UInt = 5;

	/** An internal error has occurred; this usually means a bug. */
	public static inline final INTERNAL_ERROR:UInt = 6;
}
