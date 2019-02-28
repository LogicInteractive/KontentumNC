package no.logic.uix.utils;

/**
 * ...
 * @author 
 */
class StringUtils
{
	/////////////////////////////////////////////////////////////////////////////////////
	
/*		public static function searchReplaceBrackets(inputStr:String, searchTerms:Object, outputTarget:*=null):String
	{
		var regExp:RegExp=/[{|}]/g;
		var out:String = inputStr;
		var matches:Array = inputStr.match(/\{\w+\}/g);

		for(var i:int = 0; i < matches.length; i++)
		{
			var nMatch:String = matches[i].replace(regExp, "");	
			for (var name:String in searchTerms) 
			{
				if (nMatch == name)
					out = out.replace("{"+nMatch+"}", searchTerms[name]);
			}
		}
		if (outputTarget)
			outputTarget = out;
			
		return out;
	}
	
	public static function searchReplaceDoubleBrackets(inputStr:String, searchTerms:Object, outputTarget:*=null):String
	{
		var regExp:RegExp=/[{{|}}]/g;
		var out:String = inputStr;
		var matches:Array = inputStr.match(/\{{\w+\}}/g);

		for(var i:int = 0; i < matches.length; i++)
		{
			var nMatch:String = matches[i].replace(regExp, "");	
			for (var name:String in searchTerms) 
			{
				if (nMatch == name)
					out = out.replace("{{"+nMatch+"}}", searchTerms[name]);
			}
		}
		if (outputTarget)
			outputTarget = out;
			
		return out;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	static public function dottedPriceString(value:Number):String 
	{
		var sNR:String = value.toString();
		var fAr:Array=sNR.split(".");
		var reg:RegExp=/\d{1,3}(?=(\d{3})+(?!\d))/;

		while (reg.test(fAr[0]))
		{
			fAr[0]=fAr[0].replace(reg,"$&.");
		}
		return fAr.join(".");
	}
*/		
	static public function toFirstCharUppercase(str:String):String 
	{
		if (str == null)
			return null;
			
		var converted:String = (str.substr(0,1).toUpperCase() + (str.substr(1,str.length)));
		return converted;
	}

	static public function toUppercase(str:String):String 
	{
		if (str == null)
			return null;
			
		var converted:String = str.toUpperCase();
		return converted;
	}

	static public function enforceTwoDigitNumberToString(num:Dynamic):String 
	{
		var enf:String = "";
		if (num < 10)
			enf = "0";
		enf += Std.string(num);
		return enf;
	}

	static public function enforceThreeDigitNumberToString(num:Dynamic):String 
	{
		var enf:String = "";
		if (num < 10)
			enf = "00";
		else if (num < 100)
			enf = "0";
		enf += Std.string(num);
		return enf;
	}

	static public function enforceFourDigitNumberToString(num:Dynamic):String 
	{
		var enf:String = "";
		if (num < 10)
			enf = "000";
		else if (num < 100)
			enf = "00";
		else if (num < 1000)
			enf = "0";
		enf += Std.string(num);
		return enf;
	}
/*		
	static public function numberToStringMedFortegn(numberOrInt:*):String 
	{
		var val:Number = Convert.toNumber(numberOrInt);
		if (val > 0)
			return "+" + Convert.toString(val);
		else
			return Convert.toString(val);
	}*/

	/////////////////////////////////////////////////////////////////////////////////////
	
/*		public static function stripCharactersFromString(inputString:String, charactersToRemove:String):void
	{
		var stringToStrip:String = "(jslkkkdsssd%%M3432B)";
		//say I want to remove the (, ), M, and % characters.
		var regExp:RegExp=/[(|)|M|%]/g;
		var cleanedString:String=stringToStrip.replace(regExp, "");			
	}
*/		
	static public function fixUniCodeProblems(inStr:String):String
	{
		var mrgStr = "";
		for (c in 0...inStr.length)
		{
			var cCode:Int = StringTools.fastCodeAt(inStr, c);
			switch (cCode) 
			{
				case 229:
					mrgStr += "å";
				case 197:
					mrgStr += "Å";
				case 248:
					mrgStr += "ø";
				case 216:
					mrgStr += "Ø";
				case 230:
					mrgStr += "æ";
				case 198:
					mrgStr += "Æ";
				default:
					mrgStr += String.fromCharCode(cCode);
			}
		}
		return mrgStr;
	}	
	
	static public function contains(inStr:String,match:String):Bool
	{
		if (inStr == null || match == null)
			return false;
			
		return inStr.indexOf(match) !=-1;
	}
	
	static public function returnTyped(d:String):Dynamic
	{
		if (d == null)
			return d;
			
		if (isStringBool(d))
			return Convert.toBool(d);
		else if (isStringInt(d))
			return Std.parseInt(d);
		else if (isStringInt(d))
			return Std.parseFloat(d);
		else
			return Std.string(d);
	}
	
	static public function isStringBool(inp:String):Bool
	{
		if (inp == null)
			return false;
			
		inp.split(" ").join(""); // strip spaces
			
		if ((inp.toLowerCase() == "true") || (inp.toLowerCase() == "false"))
			return true;
		else
			return false;
	}
	
	static public function isStringFloat(inp:String):Bool
	{
		if (inp == null || inp.indexOf(".")==-1)
			return false;
			
		inp.split(" ").join(""); // strip spaces
		
		for (i in 0...inp.length) 
		{
			if (!isfirstCharNumber(inp.substr(i, 1)))
				return false;
		}
		return true;
	}
	
	static public function isStringInt(inp:String):Bool
	{
		if (inp == null || inp.indexOf(".")!=-1)
			return false;
			
		inp.split(" ").join(""); // strip spaces
		for (i in 0...inp.length) 
		{
			if (!isfirstCharNumber(inp.substr(i, 1)))
				return false;
		}
		return true;
	}
	
	static public function isfirstCharNumber(char:String):Bool
	{
		if (char==null || char.length<1)
			return false;
			
		var isNumber = false;
		var fc = char.substr(0, 1);
		switch (fc) 
		{
			case "0":
				isNumber = true;
			case "1":
				isNumber = true;
			case "2":
				isNumber = true;
			case "3":
				isNumber = true;
			case "4":
				isNumber = true;
			case "5":
				isNumber = true;
			case "6":
				isNumber = true;
			case "7":
				isNumber = true;
			case "8":
				isNumber = true;
			case "9":
				isNumber = true;
			default:
				isNumber = false;
		}
		
		return isNumber;
	}
	
	static public function cleanStringAlphaNumeric(str:String) 
	{
		if (str == null)
			return null;
			
		for (i in 0...str.length) 
		{
			var cc:Int = str.charCodeAt(i);
			//trace("--", cc);
		}
		return str;
	}
	
	static public function strListToIntArray(strList:String,?delimiter:String=","):Array<Int> 
	{
		var ra:Array<Int> = [];
		var r1:Array<String> = strList.split(delimiter);
		for (i in 0...r1.length) 
		{
			ra.push(Std.parseInt(r1[i]));
		}
		return ra;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

}