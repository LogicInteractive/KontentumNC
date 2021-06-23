package;

import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import com.akifox.asynchttp.URL;
import fox.hw.tplink.TPLinkDevice.TPLink_KP105;
import fox.hw.tplink.TPLinkKasa.TPLinkKasaResponseData;
import fox.net.lan.LANScanner;
import haxe.Json;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.macro.Expr.Catch;
import haxe.macro.Expr.Error;
import no.logic.uix.utils.Convert;
import no.logic.uix.utils.ObjUtils;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import sys.net.Address;
import sys.net.Host;
import sys.net.UdpSocket;

/**
 * ...
 * @author Tommy S.
 */

class KontentumNC
{
	//static public var buildDate					: Date				= makeBuildDate();
	public static var kontentumLink				: String			= "";
	var restPingRelay							: String 			= "";
	var apiKey									: String 			= "";
	var pingTime								: Float 			= 1.0;
	var offlineTimeoutTime						: Float 			= 1.0;

	public static var httpPingClientRequest		: HttpRequest;
	var httpPingRelayRequest					: HttpRequest;
	var udpSocket								: UdpSocket;
	var udpSocket2								: UdpSocket;
	var magicPacket								: Bytes;
	var address									: Address;
	var pingTimer								: Timer;
	var timeoutTimer							: Timer;
	var localIP									: String			= "";
	var isFirstPing								: Bool				= true;
	static public var debug						: Bool;
	var settings								: Dynamic;

	var pClientsJson							: String;
	var delayedActions							: Array<WakeupAction> = [];

	var osName									: String;
	static public var netmode					: Netmode			= Netmode.ONLINE;
	static public var appDir					: String;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main()
	{
		new KontentumNC();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	public function new()
	{

		// Get proper app dir

		osName = Sys.systemName();
		if (osName=="Linux")
		{
			Projector.pjLinkPath = "./pjl";
			localIP = getLocalIP();
			
			//var dstr = buildDate.getDate()+"/"+(buildDate.getMonth()+1)+"/"+buildDate.getFullYear()+" "+buildDate.getHours()+":"+buildDate.getMinutes();
			var dstr = "";
			Sys.println('Kontentum Client :: Logic Interactive | $localIP');
		}
		else
			Projector.pjLinkPath = "pjl";

		appDir = Sys.programPath().split(".exe").join("");
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
		Projector.pjLinkPath = settings.config.kontentum.pjl;
		
		debug = Convert.toBool(settings.config.debug);

		var subnet:String = LANScanner.getSubnetFromIP(localIP);
		if (subnet!=null)
		{
			LANScanner.init(true,60*30);
			LANScanner.i.pingAllinSubnet(subnet);
			if (debug)
				LANScanner.i.traceAll();
			//var ip = LANScanner.i.getIPByMAC("00:50:41:8e:26:21");
			// if (ip!=null)
			// TPLink_KP105.toggle(ip);
		}

		udpSocket = new UdpSocket();
		// udpSocket.setBroadcast(true);

		httpPingRelayRequest = new HttpRequest({url: kontentumLink + restPingRelay + "/" + apiKey + "/" + localIP, callback: onHttpResponse});
		httpPingClientRequest = new HttpRequest({url: kontentumLink});

		startPingTimer();
		httpPingRelayRequest.clone().send();

		httpPingRelayRequest.url = new URL(kontentumLink + restPingRelay + "/" + apiKey);
	}

	function onPing()
	{
		if (netmode==Netmode.ONLINE)
		{
			if (debug)
			{
				trace("Pinging server");
				// writeToLog("Pinging server");
			}
			httpPingRelayRequest.clone().send();
		}
		else
		{
			if (debug)
			{
				trace("Client offline. Should implement this....");
				writeToLog("Client offline. Should implement this....");
			}
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function startPingTimer()
	{
		if (pingTimer != null)
			pingTimer.stop();

		if (timeoutTimer != null)
			timeoutTimer.stop();

		offlineTimeoutTime = pingTime*3;
		timeoutTimer = new Timer(Std.int(offlineTimeoutTime * 1000));
		timeoutTimer.run = onOfflineTimeout;
		pingTimer = new Timer(Std.int(pingTime * 1000));
		pingTimer.run = onPing;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onHttpResponse(response:HttpResponse)
	{
		if (response.isOK)
		{
			netmode = Netmode.ONLINE;
			timeoutTimer.stop();
			timeoutTimer.run = onOfflineTimeout;

			var rsp:PingResponse = response.toJson();
			var newPingTime:Float = rsp.ping;

			if (newPingTime > 0 && (newPingTime != pingTime))
			{
				pingTime = newPingTime;

				if (pingTime == 0)
					pingTime = settings.config.kontentum.ping;

				if (debug)
				{
				//	trace("Setting new ping time: " + newPingTime + " seconds.");
					// writeToLog("Setting new ping time: " + newPingTime + " seconds.");
				}
				//startPingTimer();
			}

			checkDelayedActions();
			processClientList(rsp.clients);

			if (rsp.all_clients!=null)
				processAllClients(rsp.all_clients);
				
			saveOfflineData(rsp);

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
			// trace(configXml);
			configFile = File.getContent(configXml);
		}
		catch (e:Dynamic)
		{
			exitWithError("Error: config.xml not found");
		}

		return ObjUtils.fromXML(Xml.parse(configFile));

		return {};
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function processClientList(pingClients:Array<PingClient>)
	{
		// var pingClients:Array<ClientInfo> = [];

		if (debug)
		{
			trace("Clients: [" + pingClients.length + "]");
			// writeToLog("Clients: [" + pingClients.length + "]");
		}
		if (pingClients.length == 0)
			return;

		for (i in 0...pingClients.length)
		{
			if (pingClients[i].mac!=null)
				pingClients[i].mac=pingClients[i].mac.toLowerCase();

			if (LANScanner.i!=null)
			{
				var tip:String = LANScanner.i.getIPByMAC(pingClients[i].mac);
				if (tip!=null && tip!="")
					pingClients[i].ip = tip;
			}
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

	function saveOfflineData(rsp:PingResponse)
	{
		try 
		{
			var pcj:String = Json.stringify(rsp.all_clients);
			if (pcj!=pClientsJson)
			{
				File.saveContent(appDir+"offlineCache",pcj);
				pClientsJson = pcj;
			}
		}
		catch(err:Dynamic)
		{
			
		}
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

	function checkDelayedActions()
	{
		if (delayedActions.length==0)
			return;

		var sNow:Int = Std.int(Timer.stamp()*1000);

		for (di in 0...delayedActions.length)
		{
			var wa:WakeupAction = delayedActions[di];
			if (wa!=null)
			{	
				var wda:Int = wa.delay*1000;
				var d:Int = sNow-wa.timestamp;
				if (d>=wda)
				{
					executeDelayedAction(wa);
					delayedActions[di]=null;
				}
			}
		}

		for (dr in 0...delayedActions.length)
		{
			if (delayedActions[dr]==null)
				delayedActions.splice(dr,1);
		}
	}

	function executeDelayedAction(wa:WakeupAction)
	{
		if (wa.type == ClientType.projector)
		{
			Projector.startup(wa.ip);
		}
		else if (wa.type == ClientType.computer)
		{
			sendMagicPacket(wa.ip, wa.mac);	
		}
		else if (wa.type == ClientType.smartplug)
		{
			SmartPlug.startup(wa.mac);
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function processAllClients(pingClients:Array<PingClient>)
	{
		for (pi in pingClients)
		{
			if (pi!=null)
				pi.mac = pi.mac.toLowerCase();
		}

		sendPingFromProjectorsThatAreOn(pingClients);
		sendPingFromSmartPlugsThatAreOn(pingClients);
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function sendPingFromSmartPlugsThatAreOn(pingClients:Array<PingClient>)
	{

		for (pi in pingClients)
		{
			if (pi.client_type==ClientType.smartplug)
			{
				if (SmartPlug.isOn(pi.mac))
				{
					var newIp:String = LANScanner.i.getIPByMAC(pi.mac);
					if (newIp!=null)
						pi.ip = newIp;
						
					KontentumNC.sendEmulatedPing(pi);
				}
			}

		}		

	}

	function sendPingFromProjectorsThatAreOn(pingClients:Array<PingClient>)
	{
		for (pi in pingClients)
		{
			if (LANScanner.i!=null)
			{
				var tip:String = LANScanner.i.getIPByMAC(pi.mac);
				if (tip!=null && tip!="")
					pi.ip = tip;
			}

	        if (pi.client_type==ClientType.projector)
			{
				Projector.query(pi.ip, (isOn:Bool)->
		        {
					if (KontentumNC.debug)
						trace("Projector "+ pi.ip +" is on : "+Std.string(isOn));
						
					if (isOn)
						KontentumNC.sendEmulatedPing(pi);
				},
				(err)->{ if (KontentumNC.debug) trace("projector query failed:"+err);});
			}

		}		

	}

	/////////////////////////////////////////////////////////////////////////////////////

	function sendWakeup(pi:PingClient)
	{

		if (pi.client_type==ClientType.projector)
		{
			//if (pi.startup_delay>0)
			//	Timer.delay(()->Projector.startup(pi.mac),pi.startup_delay*1000);
			//else
			// trace("wakeup projector : ",pi.mac,pi.ip);
			Projector.startup(pi.ip);
		}
		else if (pi.client_type==ClientType.smartplug)
		{
			if (pi.startup_delay>0)
				Timer.delay(()->SmartPlug.startup(pi.mac),pi.startup_delay*1000);
			else
				SmartPlug.startup(pi.mac);
		}
		else if (pi.client_type==ClientType.computer)
		{
			if (pi.startup_delay>0)
			{
				delayedActions.push({
					ip: pi.ip,
					mac: pi.mac,
					type: pi.client_type,
					delay: pi.startup_delay,
					timestamp: Std.int(Timer.stamp()*1000)
				});
			}
			else
				sendMagicPacket(pi.ip, pi.mac);
		}
	}

	function sendShutdown(pi:PingClient)
	{
		// pi.ip = "192.168.1.244";
		// trace("sending shutdown to.... "+pi.ip);
		if (pi.client_type==ClientType.projector)
			Projector.shutdown(pi.ip);
		else if (pi.client_type==ClientType.smartplug)
			SmartPlug.shutdown(pi.mac);
	}
/*
	@:keep
	function delayedWOL()
	{
		//delayedWOL_timer.stop();
		trace("hello!");
		sendMagicPacket(delayedWOL_ip, delayedWOL_mac);		
	}

	var delayedWOL_ip:String;
	var delayedWOL_mac:String;
	var delayedWOL_timer:Timer;
*/
	/////////////////////////////////////////////////////////////////////////////////////

	function sendMagicPacket(ip:String, macAdr:String) {
		var packet:Bytes = buildMagicPacket(macAdr);

		// var adr = new Address();
		// adr.host = new Host(ip).ip;
		// adr.port = 9; // Hardcoded for WOL

		// udpSocket.sendTo(packet, 0, packet.length, adr);

		//	var adrBR = new Address();
		//	adrBR.host = new Host("255.255.255.255").ip;
		//	adrBR.port = 9; // Hardcoded for WOL

		//	udpSocket.sendTo(packet, 0, packet.length, adrBR);

		macAdr = macAdr.split("-").join(":");
		Sys.command("wakeonlan", [macAdr]);

		if (debug)
		{
			trace("WOL packet sent to " + ip + " [" + macAdr + "]");
			writeToLog("WOL packet sent to " + ip + " [" + macAdr + "]");
		}
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

	function onOfflineTimeout()
	{
		netmode = Netmode.OFFLINE;	
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function exitWithError(msg:String)
	{
		trace(msg);
		writeToLog(msg);
		Sys.exit(1);
	}

	/////////////////////////////////////////////////////////////////////////////////////

	static public function writeToLog(msg:String)
	{
		if (debug==false)
			return;

		if (msg==null || msg=="")
			return;

		var logFile:String = "";
		if (FileSystem.exists(appDir+"log.txt"))
			logFile = File.getContent(appDir+"log.txt");

		logFile+=Date.now().toString()+"  :  ";
		logFile+=msg;
		logFile+="\n";		
		File.saveContent(appDir+"log.txt",logFile);
	}

	static public function getLocalIP():String
	{
		var p = new Process("hostname",["-I"]);  //"hostname -I | awk '{print $1}'"
		var response:String = null;
		response = p.stdout.readLine();

		//while (response!=null && response!="")
		//{
			try 
			{
				response = p.stdout.readLine();
			}
			catch(err:Dynamic)
			{
				if  (KontentumNC.debug)
				{
					trace("Failed to get local ip : "+response);
					KontentumNC.writeToLog("Failed to get local ip : "+response);
				}
			}
			//trace(response);
			if (response==null || response=="")
				return response;
			else
			{
				var respSplt:Array<String> = response.split(" ");
				if (respSplt==null || respSplt.length==0)
					return null;
				else if (respSplt.length > 0)
					return respSplt[0];
				else
					return null;
			}
		//}
		//return response;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	static public function sendEmulatedPing(pi:PingClient)
	{
		var sendURL:String = KontentumNC.kontentumLink+"/rest/pingClient/"+pi.id+"/_/"+pi.ip;
		var req = KontentumNC.httpPingClientRequest.clone();
		req.url = new URL(sendURL);
		req.callback = onPingClientResponse;
		req.send();
	}	

	static function onPingClientResponse(response:HttpResponse)
	{
		if (response!=null && response.isOK)
		{
			// trace("ping client ok");
		}
		else
		{
			trace("ping client failed!");
			KontentumNC.writeToLog("ping client failed!");
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////
/*
    macro public static function makeBuildDate():ExprOf<Date>
	{
        var date = Date.now();
        var year = toExpr(date.getFullYear());
        var month = toExpr(date.getMonth());
        var day = toExpr(date.getDate());
        var hours = toExpr(date.getHours());
        var mins = toExpr(date.getMinutes());
        var secs = toExpr(date.getSeconds());
        return macro new Date($year, $month, $day, $hours, $mins, $secs);
    }
*/
	/////////////////////////////////////////////////////////////////////////////////////

}

typedef PingResponse =
{
	var clients			: Array<PingClient>;
	var all_clients		: Array<PingClient>;
	var schedules		: Array<ScheduleItem>;
	var ping			: Float;
	var success			: Bool;
}

typedef PingClient =
{
	var exhibit_id		: Int; 
	var app_id		: Int; 
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
	var startup_delay	: Int;
}

typedef ScheduleItem =
{
	var id				: Int;
	var app_id			: Int;
	var group_id		: Int;
	var always_on		: String;
	var weekday			: String;
	var weekend			: String;
	var mon_start		: String;
	var mon_stop		: String;
	var tue_start		: String;
	var tue_stop		: String;
	var wed_start		: String;
	var wed_stop		: String;
	var thu_start		: String;
	var thu_stop		: String;
	var fri_start		: String;
	var fri_stop		: String;
	var sat_start		: String;
	var sat_stop		: String;
	var sun_start		: String;
	var sun_stop		: String;
	var group_name		: String;
	var exception		: String;
}

typedef WakeupAction = 
{
	var ip				: String;
	var mac				: String;
	var delay			: Int;
	var timestamp		: Int;
	var type			: ClientType;
}

enum Netmode
{
	ONLINE;
	OFFLINE;
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
	var smartplug		= "spp";	
}

	/////////////////////////////////////////////////////////////////////////////////////

class Projector
{
	static public var pjLinkPath		: String;

	static public function startup(ip:String,?onStartupComplete:()->Void,?onStartupFailed:()->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.startup]);
		var response:String = null;

		if  (KontentumNC.debug)
		{
			trace('send wakeup to : $ip');
			KontentumNC.writeToLog('send wakeup to : $ip');
		}
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
				response = response.split("%1").join("").toUpperCase();
				if (response=="POWR=OK")
					if (onStartupComplete!=null)
						onStartupComplete();
				else 
					if (onStartupFailed!=null)
						onStartupFailed();
			}

			if  (KontentumNC.debug)
			{
				trace("response : "+response);
				KontentumNC.writeToLog("response : "+response);
			}
		}
	}
	
	static public function shutdown(ip:String,?onShutdownComplete:()->Void,?onShutdownFailed:()->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.shutdown]);
		var response:String = null;

		if  (KontentumNC.debug)
		{
			trace('send shutdown to : $ip');
			KontentumNC.writeToLog('send shutdown to : $ip');
		}

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
				response = response.split("%1").join("").toUpperCase();
				if (response=="POWR=OK")
					if (onShutdownComplete!=null)
						onShutdownComplete();
				else 
					if (onShutdownFailed!=null)
						onShutdownFailed();

				if  (KontentumNC.debug)
				{
					trace("response : "+response);
					KontentumNC.writeToLog("response : "+response);
				}
			}
		}
		
	}
	
	static public function query(ip:String,?onQueryComplete:(on:Bool)->Void,?onQueryFailed:(err:String)->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.query]);
		var response:String = "";

		if  (KontentumNC.debug)
			trace('send query to projector : $ip');

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
			response = response.split("%1").join("").toUpperCase();
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

			// if  (KontentumNC.debug)
				// trace("response : "+response);
		}
		
	}

	/////////////////////////////////////////////////////////////////////////////////////
}

class SmartPlug
{
	static public function startup(mac:String):Bool
	{
		if (!LANScanner.active)
			return false;

		var ip = LANScanner.i.getIPByMAC(mac);

		if (KontentumNC.debug)
			trace('turn on smartplug : $ip | $mac');

		if (ip!=null)
		{
			var res:TPLinkKasaResponseData = TPLink_KP105.turnOn(ip);
			if (KontentumNC.debug)
				trace(res);			
			var isit:Bool = parseCheckIsOn(res);
			return isit==true;
		}

		return false;
	}
	
	static public function shutdown(mac:String):Bool
	{
		if (!LANScanner.active)
			return false;

		var ip = LANScanner.i.getIPByMAC(mac);

		if (KontentumNC.debug)
			trace('turn off smartplug : $ip | $mac');

		if (ip!=null)
		{
			var res:TPLinkKasaResponseData = TPLink_KP105.turnOff(ip);
			if (KontentumNC.debug)
				trace(res);			
			return parseCheckIsOn(res)==false;
		}

		return false;
	}
	
	static public function isOn(mac:String):Bool
	{
		if (!LANScanner.active)
			return false;

		var ip = LANScanner.i.getIPByMAC(mac);

		if (KontentumNC.debug)
			trace('check status smartplug : $ip | $mac');

		if (ip!=null)
		{
			var res:TPLinkKasaResponseData = TPLink_KP105.getStatus(ip);
			if (KontentumNC.debug)
				trace(res);			
			return parseCheckIsOn(res);
		}

		return false;		
	}

	static function parseCheckIsOn(rd:TPLinkKasaResponseData):Bool
	{
		if (rd==null)
			return false;

		var isOn:Bool = false;
		try
		{
			isOn = rd.system.get_sysinfo.relay_state==1;
		}
		catch(e:Dynamic)
		{
			//...
		}
		return isOn;	
	}

	/////////////////////////////////////////////////////////////////////////////////////
}
