package fox.net.lan;

import fox.utils.StringUtils;
import haxe.Timer;
import haxe.io.Bytes;
import sys.io.Process;

class LANScanner
{
	/////////////////////////////////////////////////////////////////////////////////////////

	public var computers		: Array<ARPItem> 		= [];
	var updateTimer				: Timer;

	/////////////////////////////////////////////////////////////////////////////////////////

    public function new(?scanOnInit:Bool=true,?autoUpdateIntervalInSec:Float=0)
    {
		if (autoUpdateIntervalInSec>0)
		{
			updateTimer = new Timer(Std.int(autoUpdateIntervalInSec*1000));
			updateTimer.run = scan;
		}

		if (scanOnInit)
			scan();
    }

	/////////////////////////////////////////////////////////////////////////////////////////

	public function scan()
	{
		computers.resize(0);

		var bf:Bytes = Bytes.alloc(2048);
		var p:Process = new Process("arp",["-a"]);

		var bytesAvailable:Int = 0;
		while (true)
		{
			bytesAvailable = p.stdout.readBytes(bf,0,bf.length);
			if (bytesAvailable>0)
			{
				bf = bf.sub(0,bytesAvailable);
				break;
			}
		}

		if (bf!=null && bf.length>0)
		{
			var ot:String = bf.toString();
			if (ot!=null)
			{
				var aList:Array<String> = ot.split("\r");
				for (l in aList)
				{
					l = StringUtils.remove(l, ["(",")","on","at","[ether]"]);
					var sto:String = StringUtils.truncateSpace(l,"|");
					if (sto!=null)
					{
						var ai:ARPItem = {ip:findIPfromString(sto,"|"),mac:findMACfromString(sto,"|"),isDynamic:findIsDynamicfromString(sto,"|"),name:findNamefromString(sto,"|")};
						if (ai.mac!=null)
							ai.mac=ai.mac.toLowerCase().split("-").join(":");
										
						if (ai.ip==null && ai.mac==null)
						{

						}
						else
							computers.push(ai);
					}
				}
			}
		}

	}

	/////////////////////////////////////////////////////////////////////////////////////////

	function findIPfromString(st:String,delimiter:String=" "):Null<String>
	{
		if (st==null)
			return null;

		var ffa:Array<String> = st.split(delimiter);
		if (ffa==null || ffa.length==0)
			return null;

		for (sa in ffa)
		{
			if (StringUtils.countChar(sa,".")==3) //found ip adress
			{
				return sa;
			}
		}
		return null;
	}

	function findMACfromString(st:String,delimiter:String=" "):Null<String>
	{
		if (st==null)
			return null;

		var ffa:Array<String> = st.split(delimiter);
		if (ffa==null || ffa.length==0)
			return null;

		for (sa in ffa)
		{
			sa = sa.split("-").join(":");
			if (StringUtils.countChar(sa,":")==5) //found mac adress
			{
				return sa;
			}
		}
		return null;
	}

	function findIsDynamicfromString(st:String,delimiter:String=" "):Null<Bool>
	{
		if (st==null)
			return null;

		var ffa:Array<String> = st.split(delimiter);
		if (ffa==null || ffa.length==0)
			return null;

		for (sa in ffa)
		{
			if (sa.toLowerCase()=="dynamic")
				return true;
			else if (sa.toLowerCase()=="static")
				return false;
		}
		return null;
	}

	function findNamefromString(st:String,delimiter:String=" "):Null<String>
	{
		if (st==null)
			return null;

		var ffa:Array<String> = st.split(delimiter);
		if (ffa==null || ffa.length==0)
			return null;

		for (sa in ffa)
		{
		}
		return null;
	}

	/////////////////////////////////////////////////////////////////////////////////////////

	public function getIPByMAC(macAdress:String):String
	{
		var ai:ARPItem = getByMAC(macAdress);
		if (ai!=null && ai.ip!=null)
			return ai.ip;

		return "";
	}

	public function getMACByIP(ipAdress:String):String
	{
		var ai:ARPItem = getByMAC(ipAdress);
		if (ai!=null && ai.mac!=null)
			return ai.mac;

		return "";
	}

	public function getByMAC(macAdress:String):ARPItem
	{
		if (macAdress==null)
			return null;

		macAdress = macAdress.toLowerCase().split("-").join(":");
		for (i in computers)
			if (i.mac==macAdress)
				return i;
		
		return null;
	}

	public function getByIP(ipAdress:String):ARPItem
	{
		if (ipAdress==null)
			return null;

		ipAdress = ipAdress.toLowerCase();
		for (i in computers)
			if (i.ip==ipAdress)
				return i;
		
		return null;
	}

	/////////////////////////////////////////////////////////////////////////////////////////

	public function traceAll()
	{
		for (i in computers)
			trace('ip:'+i.ip+'\t\tmac:'+i.mac+'\t'+(i.isDynamic==null?'':i.isDynamic?'dynamic':'static'));
	}

	/////////////////////////////////////////////////////////////////////////////////////////

	public function dispose()
	{
		if (updateTimer!=null)
		{
			updateTimer.stop();
			updateTimer = null;
		}	
		computers.resize(0);
		computers = null;
	}

	/////////////////////////////////////////////////////////////////////////////////////////
}

typedef ARPItem =
{
	var ?ip			: String;
	var ?mac		: String;
	var ?isDynamic	: Bool;
	var ?name		: String;
}