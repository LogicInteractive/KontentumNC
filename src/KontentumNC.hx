package;

import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import com.akifox.asynchttp.URL;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.macro.Expr.Catch;
import haxe.macro.Expr.Error;
import no.logic.uix.utils.Convert;
import no.logic.uix.utils.ObjUtils;
import sys.io.File;
import sys.io.Process;
import sys.net.Address;
import sys.net.Host;
import sys.net.UdpSocket;

/**
 * ...
 * @author Tommy S.
 */
// typedef ClientInfo = {
// 	var id:Int;
// 	var app_id:Int;
// 	var exhibit_id:Int;
// 	var name:String;
// 	var hostname:String;
// 	var ip:String;
// 	var mac:String;
// 	var launch:String;
// 	var last_ping:String;
// 	var description:String;
// 	var callback:String;
// }

class KontentumNC
{
	public static var kontentumLink:String = "";
	var restPingRelay:String = "";
	var apiKey:String = "";
	var pingTime:Float = 1.0;

	public static var httpPingClientRequest:HttpRequest;
	var httpPingRelayRequest:HttpRequest;
	var udpSocket:UdpSocket;
	var udpSocket2:UdpSocket;
	var magicPacket:Bytes;
	var address:Address;
	var pingTimer:Timer;
	var debug:Bool;
	var settings:Dynamic;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main()
	{
		new KontentumNC();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	public function new()
	{
		// Get proper app dir

		var appDir:String = Sys.programPath().split(".exe").join("");
		if (appDir.split("KontentumNC").length > 1)
		{
			var si:Int = appDir.lastIndexOf("KontentumNC");
			appDir = appDir.substring(0, si);
		}

		settings = loadSettings(appDir + "config.xml");

		if (settings == null)
			exitWithError("Error! Malformed XML");

		kontentumLink = settings.config.kontentum.ip;
		restPingRelay = settings.config.kontentum.api;
		apiKey = settings.config.kontentum.apiKey;
		pingTime = settings.config.kontentum.ping;

		debug = Convert.toBool(settings.config.debug);

		udpSocket = new UdpSocket();
		// udpSocket.setBroadcast(true);

		var sendClientIPStr:String = "/192.168.1.244";
		httpPingRelayRequest = new HttpRequest({url: kontentumLink + restPingRelay + "/" + apiKey + sendClientIPStr, callback: onHttpResponse});
		httpPingClientRequest = new HttpRequest({url: kontentumLink});

		startPingTimer();
		onPing();
	}

	function onPing()
	{
		if (debug)
			trace("Pinging server");

		httpPingRelayRequest.clone().send();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function startPingTimer()
	{
		if (pingTimer != null)
			pingTimer.stop();

		pingTimer = new Timer(Std.int(pingTime * 1000));
		pingTimer.run = onPing;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onHttpResponse(response:HttpResponse)
	{
		if (response.isOK)
		{
			var rsp:PingResponse = response.toJson();
			var newPingTime:Float = rsp.ping;

			if (newPingTime > 0 && (newPingTime != pingTime))
			{
				pingTime = newPingTime;
				pingTime = 5;

				if (pingTime == 0)
					pingTime = settings.config.kontentum.ping;

				if (debug)
					trace("Setting new ping time: " + newPingTime + " seconds.");

				startPingTimer();
			}

			// trace(rsp);
			processClientList(rsp.clients);

			if (rsp.all_clients!=null)
				processAllClients(rsp.all_clients);
				
			// trace(response.content);
			// if (response.content != null)
			// onPingData(response);
			// else
			// onPingCorruptData(response);

			// sendMagicPacket("127.0.0.1", "08:6A:0A:83:FA:15");
			// sendMagicPacket("192.168.1.10", "98:f2:b3:e7:cc:1e");
		}
		// else
		// onPingError(response);
	}

	function loadSettings(configXml:String):Dynamic
	{
		var configFile = "";
		try
		{
			configFile = File.getContent(configXml);
		}
		catch (e:Error)
		{
			exitWithError("Error: config.xml not found");
		}

		return ObjUtils.fromXML(Xml.parse(configFile));
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function processClientList(pingClients:Array<PingClient>)
	{
		// var pingClients:Array<ClientInfo> = [];

		if (debug)
			trace("Clients: [" + pingClients.length + "]");

		if (pingClients.length == 0)
			return;

		for (i in 0...pingClients.length)
		{
			if (pingClients[i].mac!=null)
				pingClients[i].mac=pingClients[i].mac.toUpperCase();
		}

		for (i in 0...pingClients.length)
		{
			sendCommandToClient(pingClients[i]);
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function sendCommandToClient(ci:PingClient)
	{
		switch (ci.callback)
		{
			case ClientCallback.wakeup:
			{
				sendWakeup(ci);
			}
			case ClientCallback.shutdown:
			{
				sendShutdown(ci);
			}
			case ClientCallback.reboot:
			{
				trace("reboot??");
			}
			default:
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function processAllClients(pingClients:Array<PingClient>)
	{
		sendPingFromProjectorsThatAreOn(pingClients);
	}

	function sendPingFromProjectorsThatAreOn(pingClients:Array<PingClient>)
	{
		for (pi in pingClients)
		{
			if (pi.client_type==ClientType.projector)
			{
				trace(pi.ip);
				Projector.query(pi.ip, (isOn:Bool)->
				{
					if (isOn)
					{
						Projector.sendPing(pi);
					}
				},(err)->trace(err));
			}
		}		

	}

	/////////////////////////////////////////////////////////////////////////////////////

	function sendWakeup(pi:PingClient)
	{
		trace("sending wakeup to:"+pi.ip);

		if (pi.client_type==ClientType.projector)
			Projector.startup(pi.ip);
		else if (pi.client_type==ClientType.computer)
			sendMagicPacket(pi.ip, pi.mac);
	}

	function sendShutdown(pi:PingClient)
	{
		pi.ip = "192.168.1.244";
		trace("sending shutdown to.... "+pi.ip);
		if (pi.client_type==ClientType.projector)
			Projector.shutdown(pi.ip);
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function sendMagicPacket(ip:String, macAdr:String) {
		var packet:Bytes = buildMagicPacket(macAdr);

		// var adr = new Address();
		// adr.host = new Host(ip).ip;
		// adr.port = 9; // Hardcoded for WOL

		// udpSocket.sendTo(packet, 0, packet.length, adr);

		/* 		var adrBR = new Address();
			adrBR.host = new Host("255.255.255.255").ip;
			adrBR.port = 9; // Hardcoded for WOL

			udpSocket.sendTo(packet, 0, packet.length, adrBR); */

		macAdr = macAdr.split("-").join(":");
		Sys.command("wakeonlan", [macAdr]);

		if (debug)
			trace("WOL packet sent to " + ip + " [" + macAdr + "]");
	}

	function buildMagicPacket(macAddr:String):Bytes
	{
		if (macAddr == null)
			return null;

		macAddr = macAddr.split("-").join(":");

		var macAddrSt:Array<String> = macAddr.split(":");
		var macAddrHex:Array<Int> = [];

		for (i in 0...macAddrSt.length)
		{
			macAddrHex.push(Std.parseInt("0x" + macAddrSt[i]));
		}

		// A magic packet is defined as : 6x0FF + 16xMAC
		var mp = Bytes.alloc(102); // 6 + (16*6)
		var ix:Int = 0;

		for (hs in 0...6)
			mp.set(ix++, 0xFF);

		for (h in 0...16)
		{
			for (hx in 0...macAddrHex.length)
			{
				mp.set(ix++, macAddrHex[hx]);
			}
		}

		return mp;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function exitWithError(msg:String)
	{
		trace(msg);
		Sys.exit(1);
	}

	/////////////////////////////////////////////////////////////////////////////////////
}

typedef PingResponse =
{
	var clients			: Array<PingClient>;
	var all_clients		: Array<PingClient>;
	var ping			: Float;
	var success			: Bool;
}

typedef PingClient =
{
	var exhibit_id 		: Int; 
	var app_id 			: Int; 
	var last_ping		: String; 
	var launch			: String; 
	var hostname		: String; 
	var name			: String;
	var id				: Int;
	var appctrl			: AppControl; 
	var description		: String;
	var client_version	: String; 
	var callback		: ClientCallback;
	var shutdown		: ComputerShutdownControl;
	var client_type		: ClientType;
	var ip				: String;
	var mac				: String;
}

enum abstract ProjectorCommand(String) to String
{
	var startup			= "POWR 1";	
	var shutdown		= "POWR 0";	
	var query			= "POWR ?";	
}

enum abstract ClientCallback(String) to String
{
	var wakeup			= "wakeup";	
	var shutdown		= "shutdown";	
	var reboot			= "reboot";	
}

enum abstract AppControl(Int) to Int
{
	var enabled			= 1;	
	var disabled		= 0;	
}

enum abstract ComputerShutdownControl(Int) to Int
{
	var canShutdown		= 1;	
	var cannotShutdown	= 0;	
}

enum abstract ClientType(String) to String
{
	var computer		= "cmp";	
	var projector		= "prj";	
}

	/////////////////////////////////////////////////////////////////////////////////////

class Projector
{
	static final pjLinkPath		: String			= "pj/pjlink";

	static public function startup(ip:String,?onStartupComplete:()->Void,?onStartupFailed:()->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.startup]);
		var response:String = null;
		
		while (response!=null && response!="")
		{
			try 
			{
				response = p.stdout.readLine();
			}
			catch(err:Dynamic)
			{

			}

			if (response!=null && response.length>0)
			{
				p.close();
				response = response.split("%1").join("");
				if (response=="POWR=OK")
					if (onStartupComplete!=null)
						onStartupComplete();
				else 
					if (onStartupFailed!=null)
						onStartupFailed();
			}
		}
		
	}
	
	static public function shutdown(ip:String,?onShutdownComplete:()->Void,?onShutdownFailed:()->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.shutdown]);
		var response:String = null;
		
		while (response!=null && response!="")
		{
			try 
			{
				response = p.stdout.readLine();
			}
			catch(err:Dynamic)
			{

			}

			if (response!=null && response.length>0)
			{
				p.close();
				response = response.split("%1").join("");
				if (response=="POWR=OK")
					if (onShutdownComplete!=null)
						onShutdownComplete();
				else 
					if (onShutdownFailed!=null)
						onShutdownFailed();
			}
		}
		
	}
	
	static public function query(ip:String,?onQueryComplete:(on:Bool)->Void,?onQueryFailed:(err:String)->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.query]);
		var response:String = "";
		while (response==null || response=="")
		{
			try 
			{
				response = p.stdout.readLine();
			}
			catch(err:Dynamic)
			{

			}
		}
		if (response!=null && response!="")
		{
			p.close();
			response = response.split("%1").join("");
			if (response=="POWR=1")
			{
				if (onQueryComplete!=null)
				{
					onQueryComplete(true);
				}
			}
			else if (response=="POWR=0")
			{
				if (onQueryComplete!=null)
				{
					onQueryComplete(false);
				}
			}
			else 
				if (onQueryFailed!=null)
					onQueryFailed(response);
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	static public function sendPing(pi:PingClient)
	{
		// trace("ping projector:"+pi.ip);
		var req = KontentumNC.httpPingClientRequest.clone();
		req.url = new URL(KontentumNC.kontentumLink+"/rest/pingClient/"+pi.id+"/"+pi.ip);
		req.callback = onPingClientResponse;
		req.send();
	}	

	static function onPingClientResponse(response:HttpResponse)
	{
		if (response!=null && response.isOK)
			trace("ping client ok");
		else
			trace("ping client failed!");
	}

	/////////////////////////////////////////////////////////////////////////////////////
}