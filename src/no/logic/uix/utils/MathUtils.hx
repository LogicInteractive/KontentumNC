package no.logic.uix.utils;

/**
 * ...
 * @author 
 */
class MathUtils
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	static public function distanceBetweenTwoPoints(x1:Float,y1:Float,x2:Float,y2:Float):Float
	{
		var dx:Float = x1 - x2;
		var dy:Float = y1 - y2;
		return Math.sqrt(dx * dx + dy * dy);
	}
	
	static public function radiansBetweenTwoPoints(x1:Float,y1:Float,x2:Float,y2:Float):Float
	{
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		return Math.atan2(dy,dx);
	}
	
	static public function angleBetweenTwoPoints(x1:Float,y1:Float,x2:Float,y2:Float,normalized:Bool=false):Float
	{
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		var mx = Math.atan2(dy, dx) / Math.PI;
		mx -= 0.5;
		if (mx < 0)
			mx += 2;
		if (normalized)
			return (mx * 0.5);
		else
			return (mx * 0.5) * 360;
	}
	
	static public function pointInEllipse(pX:Float, pY:Float, centerX:Float, centerY:Float, width:Float, height:Float):Bool
	{
		var dx = pX - centerX;
		var dy = pY - centerY;
		return ( dx * dx ) / ( width * width ) + ( dy * dy ) / ( height * height ) <= 1;
	}
	
	static public function radiansToDegrees(radians:Float):Float
	{
		return radians * 180/Math.PI;
	}	
	
	static public function degreesToRadians(degrees:Float):Float 
	{
		return degrees * Math.PI / 180;
	}
 
	public static function rangeMapper(num:Float, min1:Float, max1:Float, min2:Float, max2:Float, round:Bool = false, constrainMin:Bool = true, constrainMax:Bool = true):Float
	{
		if (constrainMin && num < min1) return min2;
		if (constrainMax && num > max1) return max2;
	 
		var num1:Float = (num - min1) / (max1 - min1);
		var num2:Float = (num1 * (max2 - min2)) + min2;
		if (round) return Math.round(num2);
		return num2;
	}	
	
	public static function clamp(val:Float, min:Float=0, max:Float=1)
	{
		return Math.max(min, Math.min(max, val));
	}	
	
	static public function getRandomIntInRange(minNum:Int, maxNum:Int):Int
	{
		return Math.floor( (Math.random() * (maxNum - minNum)) ) + minNum;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

}