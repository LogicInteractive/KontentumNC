package no.logic.uix.utils;

import haxe.Timer;
//import openfl.Lib;

/**
 * ...
 * @author 
 */
class TimeUtils
{
/*	/////////////////////////////////////////////////////////////////////////////////////
		
	private static var _stopWatch			: StopWatch;
	public static var weekdays				: Array 			= ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
		
	/////////////////////////////////////////////////////////////////////////////////////
*/		
	static var prevTime					: Float = 0;
	static var step						: Int;
	static var ftimer					: Float;
	static inline var TARGET_INTERVAL	: Float = 1000 / 60;

	#if (!js && !flash)
	
	public static function sleepFrame() 
	{
		step = Timer.stamp() - prevTime;
		prevTime += step;
		ftimer = (TARGET_INTERVAL - (Timer.stamp() - prevTime));
		prevTime = Timer.stamp();
    
		if (ftimer > 0) 
		{
			Sys.sleep( ftimer / 1000 );
		}
	}	
	
	#end
	
	public static function getFormatedTimeStamp():String 
	{
		var date:Date = Date.now();
		var eTime:String = "";
		var eHours:Float = date.getHours();
		var eMinut:Float = date.getMinutes();
		var eSecon:Float = date.getSeconds();
		eHours < 10 ? eTime+="0"+Std.int(eHours) : eTime+=Std.int(eHours);
		eTime+= ":";
		eMinut < 10 ? eTime+="0"+Std.int(eMinut) : eTime+=Std.int(eMinut);
		eTime+= ":";
		eSecon < 10 ? eTime+= "0" + Std.int(eSecon) : eTime+= Std.int(eSecon);
		
		return eTime;
	}
	
	//public static function timeout(closure:Void->Void, time)
	//{
		//var hxTim:Timer = Timer.delay
	//}
/*		
		public static function getFormatedDateAndTimeStamp():String 
		{
			var date:Date = new Date();
			var eTime:String = "";
			var eDay:String = weekdays[date.getDay()];
			var eDate:Number = date.getDate();
			var eMonth:Number = date.getMonth()+1;
			var eYear:Number = date.getFullYear();
			var eHours:Number = date.getHours();
			var eMinut:Number = date.getMinutes();
			var eSecon:Number = date.getSeconds();
			eTime += eDay + " ";
			eDate < 10 ? eTime+="0"+eDate.toFixed() + "/" : eTime+=eDate.toFixed() + "/";
			eMonth < 10 ? eTime+="0"+eMonth.toFixed() : eTime+=eMonth.toFixed();
			eTime += "/" + eYear.toString() + " ";
			eHours < 10 ? eTime+="0"+eHours.toFixed() : eTime+=eHours.toFixed();
			eTime+= ":";
			eMinut < 10 ? eTime+="0"+eMinut.toFixed() : eTime+=eMinut.toFixed();
			eTime+= ":";
			eSecon < 10 ? eTime+="0"+eSecon.toFixed() : eTime+=eSecon.toFixed();
			return eTime;
		}
		
		public static function getFormatedDate():String 
		{
			var date:Date = new Date();
			var eTime:String = "";
			var eDay:String = weekdays[date.getDay()];
			var eDate:Number = date.getDate();
			var eMonth:Number = date.getMonth()+1;
			var eYear:Number = date.getFullYear();
			var eHours:Number = date.getHours();
			var eMinut:Number = date.getMinutes();
			var eSecon:Number = date.getSeconds();
			eTime += eDay + " ";
			eDate < 10 ? eTime+="0"+eDate.toFixed() + "/" : eTime+=eDate.toFixed() + "/";
			eMonth < 10 ? eTime+="0"+eMonth.toFixed() : eTime+=eMonth.toFixed();
			eTime += "/" + eYear.toString() + " ";
			return eTime;
		}
		
		static public function get stopWatch():StopWatch 
		{
			if (!_stopWatch)
				_stopWatch = new StopWatch;
				
			return _stopWatch;
		}
*/		
		static public function convertToHHMMSS(seconds:Float):String
		{
			var s:Int = Math.floor(seconds % 60);
			var m:Int = Math.floor((seconds % 3600 ) / 60);
			var h:Int = Math.floor(seconds / (60 * 60));
			 
			var hourStr:String = (h == 0) ? "" : doubleDigitFormat(h) + ":";
			var minuteStr:String = doubleDigitFormat(m) + ":";
			var secondsStr:String = doubleDigitFormat(s);
			 
			return hourStr + minuteStr + secondsStr;
		}
		 
		static private function doubleDigitFormat(num:Int):String
		{
			if (num < 10) 
			{
				return "0" + num;
			}
			return Std.string(num);
		}

		/////////////////////////////////////////////////////////////////////////////////////
	//}
/*}
	import flash.utils.getTimer;

	internal class StopWatch
	{
		private var timerPool:Object = {};
			
		public function start(id:String):void
		{
			timerPool[id] = getTimer();
		}
		
		public function stop(id:String):int
		{
			var result:int = getTimer() - timerPool[id];
			return result;
		}
		
		public function getTime(id:String):int
		{
			var result:int = getTimer() - timerPool[id];
			return result;
		}
		
		public function clear(id:String):void
		{
			if (id in timerPool)
				delete timerPool[id];
		}
*/	
}