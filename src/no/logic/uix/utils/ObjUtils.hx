package no.logic.uix.utils;
//import openfl.utils.Object;

/**
 * ...
 * @author Tommy S.
 */

class ObjUtils
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	public static function toString(obj:Dynamic):String
	{
		if (obj == null)
			return null;
			
		var retStr = "";
		for (name in Reflect.fields(obj))
		{		
			var val = Reflect.getProperty(obj, name);
			retStr += '"' + name+'":' + Std.string(val) + ", ";
		}
		return retStr.substr(0,retStr.length-2);
	}
	
	public static function copyProperties(source:Dynamic,dest:Dynamic=null,deepCopy:Bool=true,checkIfHasProperty:Bool=false):Dynamic
	{
		if (source!=null)
		{
			if (dest==null)
				dest = {};
			
			var destFields = Reflect.fields(dest);
			for (name in Reflect.fields(source))
			{
				if (checkIfHasProperty)
				{
					if (destFields.indexOf(name)!=-1)
					{
						Reflect.setProperty(dest, name, Reflect.getProperty(source, name));
					}
				}
				else
				{
					Reflect.setProperty(dest, name, Reflect.getProperty(source, name));
				}
			}
		}
		
		return dest;
	}
	
	public static function getObjLength(obj:Dynamic):Int
	{
		var nums:Int = 0;
		if (obj!=null)
		{
			for (name in Reflect.fields(obj))
			{
				nums++;
			}
		}
		return nums;
	}
	
	public static function isEmpty(obj:Dynamic):Bool
	{
		if (obj == null)
			return true;
			
		return Reflect.fields(obj).length == 0;
	}
/*
	public static function clone(reference:*) : Object
	{
		var clone:ByteArray = new ByteArray();
		clone.writeObject( reference );
		clone.position = 0;

		return clone.readObject();
	}
	
	static public function getTypeClassFromTypedArray(source:Object):Class 
	{
		var returnClass:Class;
		var desc:XML = describeType(source);
		var typeName:String = desc.@name;
		var baseName:String = desc.@base;
		if (baseName && (baseName.indexOf("<*>") != -1))
		{
			var bn2:String = baseName.split("*")[0];
			var typeClassName:String = typeName.split(bn2)[1].slice(0,-1);
			returnClass = getDefinitionByName(typeClassName) as Class;
		}
		else
			returnClass = Object;
		
		return returnClass;
	}
*/
	public static function hasProperty(obj:Dynamic, propertyName:String, checkForNullValue:Bool=true):Bool
	{
		if (obj!=null && propertyName!=null)
		{
			var keys = Reflect.fields(obj);
			if (keys.indexOf(propertyName) !=-1)
			{
				if (checkForNullValue)
				{
					if (Reflect.getProperty(obj,propertyName) != null)
						return true;
				}
				else
				{
					return true;
				}
						
			}
		}
		return false;
	}
	
	static public function getRandomPropertyName(obj:Dynamic):String 
	{
		if (obj == null)
			return null;
			
		var oLen:Int = getObjLength(obj);
		var rnd:Int = Std.int(Math.random() * oLen);
		var cc:Int = 0;
		for (name in Reflect.fields(obj))
		{
			if (cc >= rnd)
			{
				return name;
			}
			cc++;
		}
		return null;
	}
	
	static public function toArray(obj:Dynamic):Array<Dynamic> 
	{
		var retArr:Array<Dynamic> = [];
		if (obj)
		{
			for (name in Reflect.fields(obj))
			{		
				var val = Reflect.getProperty(obj, name);
				retArr.push(val);
			}
		}
		return retArr;			
	}
	
	static public function propertyNamesToArray(obj:Dynamic, ?check:Dynamic=null):Array<Dynamic>
	{
		var retArr:Array<Dynamic> = [];
		if (obj!=null)
		{
			for (name in Reflect.fields(obj))
			{		
				if (check != null)
				{
					if (Reflect.getProperty(obj, name) == check)
						retArr.push(name);
				}
				else
					retArr.push(name);
			}
		}
		return retArr;			
	}
	
	static public function fromXML(xml:Xml):Dynamic
	{
		var o:Dynamic = {};
		if (xml != null)
		{
			iterateXMLNode(o, xml);
		}
		return o;
	}
	
	static function iterateXMLNode(o:Dynamic, xml:Xml) 
	{
		for ( node in xml.elements() )
		{
			if (node!=null)
			{	
				var nodeChildren = 0;
				for ( nc in node.elements() )
					nodeChildren++;
					
				if (nodeChildren>0)
				{
					Reflect.setField(o, node.nodeName, {});
					iterateXMLNode(Reflect.field(o, node.nodeName), node);
				}
				else
					Reflect.setField(o, node.nodeName, StringUtils.returnTyped(Std.string(node.firstChild())));
			}
		}		
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
}
