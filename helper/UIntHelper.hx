package helper;

/**
 * ...
 * @author Christopher Speciale
 */
//Haxe currently doesn't allow translation of an UInt larger than max integer into UInt as a literal so this is the hack-around.
// usage var n:UInt = UIntHelper.literalToUInt(4294967295);
class UIntHelper 
{
	
	public static function literalToUInt(f:Float):UInt{
		var h:Float = f / 2;
		
		return Std.int(h) + Std.int(h) + (h % 1 == 0 ? 0 : 1);
	}	
	
}