package;

import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.macro.Expr.Error;
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

typedef ClientInfo =
{
	var id				: Int;
	var app_id			: Int;
	var exhibit_id		: Int;
	var name			: String;
	var hostname		: String;
	var ip				: String;
	var mac				: String;
	var launch			: String;
	var last_ping		: String;
	var description		: String;
	var callback		: String;
}

class KontentumNC 
{
	//===================================================================================
	// Main 
	//-----------------------------------------------------------------------------------
	
	var kontentumLink		: String				= "";
	var restPingRelay		: String				= "";
	var apiKey				: String				= "";
	var pingTime			: Float					= 1.0;
	
	/////////////////////////////////////////////////////////////////////////////////////

	var httpPingRequest		: HttpRequest;
	var udpSocket			: UdpSocket;
	var magicPacket			: Bytes;
	var address				: Address;
	var pingTimer			: Timer;

	var settings			: Dynamic;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main() { new KontentumNC(); }
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public function new()
	{
		settings = loadSettings("config.xml");
		if (settings == null)
			exitWithError("Error! Malformed XML");
			
		kontentumLink = settings.config.kontentum.ip;
		restPingRelay = settings.config.kontentum.api;
		apiKey = settings.config.kontentum.apiKey;
		pingTime = settings.config.kontentum.ping;
			
		udpSocket = new UdpSocket();
	
		httpPingRequest = new HttpRequest( { url:kontentumLink+restPingRelay+"/"+apiKey, callback:onHttpResponse });		
		
		startPingTimer();
		onPing();
	}
	
	function onPing() 
	{
		trace("Pinging server");
		httpPingRequest.clone().send();
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

	function startPingTimer() 
	{
		if (pingTimer != null)
			pingTimer.stop();
			
		pingTimer = new Timer(Std.int(pingTime*1000));
		pingTimer.run = onPing;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

	function onHttpResponse(response:HttpResponse)
	{
		if (response.isOK)
		{
			var rsp:Dynamic = response.toJson();
			var newPingTime:Float = Std.parseFloat(rsp.ping);
			if (newPingTime > 0 && (newPingTime!=pingTime))
			{
				pingTime = newPingTime;
				if (pingTime == 0)
					pingTime = settings.config.kontentum.ping;
					
				trace("Setting new ping time: " + newPingTime + " seconds.");
				startPingTimer();
			}
				
			processClientList(rsp.clients);
			//trace(response.content);
			//if (response.content != null)
				//onPingData(response);
			//else
				//onPingCorruptData(response);
				
			//sendMagicPacket("127.0.0.1", "08:6A:0A:83:FA:15");
			//sendMagicPacket("192.168.1.10", "98:f2:b3:e7:cc:1e");
		}
		//else
			//onPingError(response);
	}  

	//===================================================================================
	// Load settings 
	//-----------------------------------------------------------------------------------

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
	
	function processClientList(clientArr:Array<Dynamic>) 
	{
		var pingClients:Array<ClientInfo> = [];
		trace("Clients: ["+pingClients.length+"]");
		
		if (pingClients.length == 0)
			return;
			
		for (i in 0...clientArr.length) 
		{
			pingClients.push(
			{
				id				: clientArr[i].id,
				app_id			: clientArr[i].app_id,
				exhibit_id		: clientArr[i].exhibit_id,
				name			: clientArr[i].name,
				hostname		: clientArr[i].hostname,
				ip				: clientArr[i].ip,
				mac				: clientArr[i].mac.toUpperCase(),
				launch			: clientArr[i].launch,
				last_ping		: clientArr[i].last_ping,
				description		: clientArr[i].description,
				callback		: clientArr[i].callback
			});
		}	
		
		for (i in 0...pingClients.length) 
		{
			processClient(pingClients[i]);
		}
	}
	
	function processClient(ci:ClientInfo) 
	{
		switch (ci.callback) 
		{
			case "wakeup":
			{
				sendMagicPacket(ci.ip, ci.mac);
			}
		}
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	function sendMagicPacket(ip:String, macAdr:String)
	{
		var packet:Bytes = buildMagicPacket(macAdr);
		
		var adr = new Address();
		adr.host = new Host(ip).ip;
		adr.port = 9; //Hardcoded for WOL

		udpSocket.sendTo(packet, 0, packet.length, adr);	
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
			macAddrHex.push(Std.parseInt("0x"+macAddrSt[i]));
		}
		
		//A magic packet is defined as : 6x0FF + 16xMAC
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

