package no.logic.uix;

import no.logic.uix.UIX.UIXMouseEventsRemove;
import no.logic.uix.console.UIXConsole;
import no.logic.uix.core.application.App;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;

/**
 * ...
 * @author 
 */

/////////////////////////////////////////////////////////////////////////////////////////
 
typedef UIXEventItem =
{
				var eventName		: String;
				var callback		: Dynamic->Void;
	@:optional	var properties		: Dynamic;
}
 
typedef UIXEvents =
{
	@:optional	var app				: UIXAppEvents;
	@:optional	var mouse			: UIXMouseEvents;
	@:optional	var sound			: Dynamic;
}
 
class UIXAppEvents
{
	public function new() {}
	
	public var remove				: UIXMouseEventsRemove = new UIXMouseEventsRemove();
	
	public function enterFrame(callBack:Dynamic->Void, ?target:Dynamic=null)
	{
		if (target == null)
			target = App.stage_;
			
		if (callBack != null)
		{
			target.addEventListener(Event.ENTER_FRAME, callBack);
		}
	}	
	
	public function enterFrameRemove(callBack:Dynamic->Void, ?target:Dynamic=null)
	{
		if (target == null)
			target = App.stage_;
			
		if (callBack != null)
		{
			target.removeEventListener(Event.ENTER_FRAME, callBack);
		}
	}
}

class UIXMouseEvents
{
	public function new() {}
	
	public var remove				: UIXMouseEventsRemove = new UIXMouseEventsRemove();
	
	public function click(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.CLICK, callBack);
		}
	}
	
	public function rightClick(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.RIGHT_CLICK, callBack);
		}
	}
	
	public function press(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.MOUSE_DOWN, callBack);
		}
	}
	
	public function release(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.MOUSE_UP, callBack);
		}
	}
	
	public function over(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.MOUSE_OVER, callBack);
		}
	}
	
	public function out(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.addEventListener(MouseEvent.MOUSE_OUT, callBack);
		}
	}
	
	//@:optional	var click 			: Dynamic->Sprite->Void;
	
	//@:isVar public var click(get, set): Dynamic->Void;
	//function set_click(cc:Dynamic)	: Dynamic->Void
	//{
		//trace(cc);
		//return click;
	//}
	//function get_click()	: Dynamic->Void
	//{
		//return click;
	//}	
	//
	//@:optional	var down 			: Dynamic;
	//@:optional	var up 				: Dynamic;
	//@:optional	var over			: Dynamic;
	//@:optional	var out				: Dynamic;
}

class UIXMouseEventsRemove
{
	public function new() {}
	
	public function click(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.CLICK, callBack);
		}
	}
	
	public function rightClick(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.RIGHT_CLICK, callBack);
		}
	}
	
	public function press(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.MOUSE_DOWN, callBack);
		}
	}
	
	public function release(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.MOUSE_UP, callBack);
		}
	}
	
	public function over(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.MOUSE_OVER, callBack);
		}
	}
	
	public function out(target:Dynamic, callBack:Dynamic->Void)
	{
		if (target != null && callBack != null)
		{
			target.removeEventListener(MouseEvent.MOUSE_OUT, callBack);
		}
	}
	
	//@:optional	var click 			: Dynamic->Sprite->Void;
	
	//@:isVar public var click(get, set): Dynamic->Void;
	//function set_click(cc:Dynamic)	: Dynamic->Void
	//{
		//trace(cc);
		//return click;
	//}
	//function get_click()	: Dynamic->Void
	//{
		//return click;
	//}	
	//
	//@:optional	var down 			: Dynamic;
	//@:optional	var up 				: Dynamic;
	//@:optional	var over			: Dynamic;
	//@:optional	var out				: Dynamic;
}

/////////////////////////////////////////////////////////////////////////////////////////

class UIX
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Consts 
	//-----------------------------------------------------------------------------------

	//===================================================================================
	// Properties 
	//-----------------------------------------------------------------------------------
	
	private static var eventPool		: Map<String, UIXEventItem>		= new Map<String, UIXEventItem>();
	
	//===================================================================================
	// Declarations 
	//-----------------------------------------------------------------------------------

	//===================================================================================
	// Variables 
	//-----------------------------------------------------------------------------------		

	static var _intCount				: Int				= 0;
	static var uixevents				: UIXEvents;
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public static var c(get, null) : no.logic.uix.console.UIXConsole;
	static function get_c():no.logic.uix.console.UIXConsole 
	{
		return no.logic.uix.console.UIXConsole.i;
	}	
	
	public static var e(get, null) : UIXEvents;
	static function get_e():UIXEvents 
	{
		if (uixevents == null)
		{
			uixevents = 
			{ 
				app		: new UIXAppEvents(),
				mouse 	: new UIXMouseEvents() 
			};
		}
		return uixevents;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public static function add(eventName:String, callback:Dynamic->Void, ?properties:Dynamic):UIXEventItem
	{
		_intCount++;
		var nen = eventName+"__$ic" + Std.string(_intCount);
		eventPool.set(nen, { eventName:eventName, callback:callback, properties:properties } );
		return eventPool.get(nen);
	}	
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public static function remove(eventName:String, callback:Dynamic->Void)
	{
		for ( key in eventPool.keys() )
		{
			var sk = key.split("__$ic")[0];
			if (sk == eventName && callback == callback)
			{
				eventPool[key] = null;
				eventPool.remove(key);
			}
		}
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public static function dispatch(eventName:String, ?properties:Dynamic):Class<UIX>
	{
		doDispatch(eventName, properties);
		return no.logic.uix.UIX;
	}
	
	static private function doDispatch(eventName:String, ?properties:Dynamic) 
	{
		for ( key in eventPool.keys() )
		{
			var sk = key.split("__$ic")[0];
			if (sk == eventName)
			{
				eventPool[key].callback(properties);
			}
		}
		  
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
}

