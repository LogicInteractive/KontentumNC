package;

import HttpRequest2;
import com.akifox.asynchttp.URL;
import fox.compile.CompileTime;
import fox.hw.tplink.TPLinkDevice.TPLink_KP105;
import fox.hw.tplink.TPLinkKasa.TPLinkKasaResponseData;
import fox.net.lan.LANScanner;
import fox.utils.DateUtils;
import haxe.Json;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.macro.Expr.Catch;
import haxe.macro.Expr.Error;
import no.logic.uix.utils.Convert;
import no.logic.uix.utils.MathUtils;
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
	// Add these properties to your KontentumNC class
	private static inline var MAX_CONSECUTIVE_FAILURES 		= 5;
	private static inline var INITIAL_RETRY_DELAY 			= 1000; // ms
	private static inline var MAX_RETRY_DELAY 				= 5000; // ms

	private var consecutiveFailures:Int 					= 0;
	private var retryDelay:Int 								= INITIAL_RETRY_DELAY;

	//static public var buildDate				: Date				= makeBuildDate();
	public static var i							: KontentumNC;
	public static var kontentumLink				: String			= "";
	public var restRelayCallback				: String 			= "/rest/relayCallback";
	var restPingRelay							: String 			= "";
	var apiKey									: String 			= "";
	public var pingTime							: Float 			= 1.0;
	public var offlineTimeout					: Float 			= 1.0;
	var offlineTimeoutTime						: Float 			= 1.0;

	public static var httpPingClientRequest		: HttpRequest2;
	var httpPingRelayRequest					: HttpRequest2;
	public static var httpAsync					: Bool				= true;
	var udpSocket								: UdpSocket;
	var udpSocket2								: UdpSocket;
	var magicPacket								: Bytes;
	var address									: Address;
	var pingTimer								: Timer;
	var timeoutTimer							: Timer;
	var localIP									: String			= "";
	var isFirstPing								: Bool				= true;
	var retryPing								: Bool				= false;
	static var canWriteToLog					: Bool				= true;
	static public var debug						: Bool;
	var settings								: Dynamic;

	var pClientsJson							: String;
	var delayedActions							: Array<WakeupAction> = [];

	var osName									: String;
	static public var netmode					: Netmode			= Netmode.ONLINE;
	static public var appDir					: String;
	static public var buildDate					: Date				= CompileTime.buildDate();

	var jobTracker								: JobTracker;
	var offlineTracker							: OfflineTracker;
	var pingCounter								: Int					= 0;
	var metricsTimer							: Timer;
	var startTime								: Float;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main()
	{
		i = new KontentumNC();
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
			
			var bDate:String = DateUtils.getFormattedDate(buildDate);
			//var dstr = buildDate.getDate()+"/"+(buildDate.getMonth()+1)+"/"+buildDate.getFullYear()+" "+buildDate.getHours()+":"+buildDate.getMinutes();
			var dstr = "";
			Sys.println('Kontentum Client :: Logic Interactive | $localIP | Build: $bDate');
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
		offlineTimeout = settings.config.kontentum.offlineTimeout;
		Projector.pjLinkPath = settings.config.kontentum.pjl;
		
		debug = Convert.toBool(settings.config.debug);
		// Logging enabled - controlled by config.xml <debug> setting
		canWriteToLog = debug;

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

		jobTracker = new JobTracker(this);
		offlineTracker = new OfflineTracker(this,offlineTimeout);

		// Start metrics tracking
		startTime = Timer.stamp();
		initializeMetricsLog();
		metricsTimer = new Timer(60000); // Log metrics every 60 seconds
		metricsTimer.run = logResourceMetrics;

		if (debug)
			trace("Connecting to Kontentum.... ");

		httpPingRelayRequest = new HttpRequest2({url: kontentumLink + restPingRelay + "/" + apiKey + "/" + StringTools.urlEncode(localIP) + "/" + StringTools.urlEncode(buildDate.toString()), callback: onHttpResponse, callbackError:onHttpError, async:httpAsync});
		// httpPingRelayRequest.timeout = 1;//Std.int(Math.floor(pingTime-1.0));
		httpPingRelayRequest.timeout = Std.int(Math.floor(pingTime-1.0));
		httpPingClientRequest = new HttpRequest2({url: kontentumLink, async:httpAsync});
		// trace(httpPingRelayRequest.url);

		startPingTimer();
		httpPingRelayRequest.clone().send();

		httpPingRelayRequest.url = new URL(kontentumLink + restPingRelay + "/" + apiKey);
	}

	function onPing()
	{
		pingCounter++;

		if (netmode==Netmode.ONLINE)
		{
			if (debug)
			{
				trace("Pinging server");
				// writeToLog("Pinging server");
			}
			if (retryPing)
				retryPingRequest();
			else
				httpPingRelayRequest.clone().send();
		}
		else
		{
			if (debug)
			{
				trace("Client offline. Should implement offline mode.... Will retry connection...");
				writeToLog("Client offline. Should implement offline mode.... Will retry connection...");
			}
			httpPingRelayRequest.clone().send();
		}

		// trace('Consecutive failures: $consecutiveFailures');
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

	function onHttpResponse(response:HttpResponse2)
	{
		if (response.isOK)
		{
			consecutiveFailures = 0;
			retryDelay = INITIAL_RETRY_DELAY;
        
			offlineTracker.gotPing();
			timeoutTimer.stop();
			timeoutTimer.run = onOfflineTimeout;
			if (netmode==Netmode.OFFLINE)
				LANScanner.i.reTrigger(localIP,debug);
				
			netmode = Netmode.ONLINE;
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

			if (rsp.callback!=null && rsp.callback!="")
				processLocalCallback(rsp.callback);

			if (rsp.url_jobs!=null)
			{
				trace(response.content);
				// trace(rsp.timestamp);
				jobTracker.processUrlJobs(rsp.url_jobs);
			}

			// trace(response.content);
			// if (response.content != null)
			// onPingData(response);
			// else
			// onPingCorruptData(response);

			// sendMagicPacket("127.0.0.1", "08:6A:0A:83:FA:15");
			// sendMagicPacket("192.168.1.10", "98:f2:b3:e7:cc:1e");
		}
		else
		{
			trace("ERROR : ",response.url.toString());
			trace("ERROR : ",response);
			onHttpError(response);
		}
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

	// function onHttpError(response:HttpResponse) 
	// {
	// 	if (debug)
	// 	{
	// 		trace("HTTP error: "+response.toString());
	// 		trace("Will retry connection...");
	// 	}

	// 	netmode=Netmode.OFFLINE;
	// 	httpPingRelayRequest = httpPingRelayRequest.clone();
	// 	httpPingRelayRequest.send();
	// }

	function onHttpError(response:HttpResponse2) 
	{
		if (debug)
		{
			trace("HTTP error: "+response.toString());
		}
		
		// netmode = Netmode.OFFLINE;
		consecutiveFailures++;
		
		// #if cpp
		// cpp.vm.Gc.run(true);
		// #end
		
		retryPing = true;
	}

	function retryPingRequest()
	{
		// trace("retry ping");
		httpPingRelayRequest = new HttpRequest2({
			url: kontentumLink + restPingRelay + "/" + apiKey, 
			callback: onHttpResponse, 
			callbackError: onHttpError,
			async:httpAsync
		});
		// httpPingRelayRequest.timeout = 1;//Std.int(Math.floor(pingTime-1.0));
		httpPingRelayRequest.timeout = Std.int(Math.floor(pingTime-1.0));
		httpPingRelayRequest.send();
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

		// sendPingFromProjectorsThatAreOn(pingClients);
		sendStatusFromProjectors(pingClients);
		// sendPingFromSmartPlugsThatAreOn(pingClients);
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

	function sendStatusFromProjectors(pingClients:Array<PingClient>)
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
				Projector.query(pi.ip, (state:Int)->
		        {
					if (KontentumNC.debug)
						trace("Projector "+ pi.ip +" has state on : "+state);
						
					// if (isOn)
						// KontentumNC.sendEmulatedPing(pi);
					Projector.sendKontentumCallback(pi,state);
				},
				(err)->{ if (KontentumNC.debug) trace("projector query failed:"+err);});
			}

		}		

	}

	// function sendPingFromProjectorsThatAreOn(pingClients:Array<PingClient>)
	// {
	// 	for (pi in pingClients)
	// 	{
	// 		if (LANScanner.i!=null)
	// 		{
	// 			var tip:String = LANScanner.i.getIPByMAC(pi.mac);
	// 			if (tip!=null && tip!="")
	// 				pi.ip = tip;
	// 		}

	//         if (pi.client_type==ClientType.projector)
	// 		{
	// 			Projector.query(pi.ip, (isOn:Bool)->
	// 	        {
	// 				if (KontentumNC.debug)
	// 					trace("Projector "+ pi.ip +" is on : "+Std.string(isOn));
						
	// 				if (isOn)
	// 					KontentumNC.sendEmulatedPing(pi);
	// 			},
	// 			(err)->{ if (KontentumNC.debug) trace("projector query failed:"+err);});
	// 		}

	// 	}		

	// }

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

	static public function writeToLog(msg:String, ?level:String="INFO")
	{
		if (debug==false || !canWriteToLog)
			return;

		if (msg==null || msg=="")
			return;

		try {
			var logPath = appDir+"log.txt";

			// Rotate log if it exceeds 10MB
			if (FileSystem.exists(logPath)) {
				var stat = FileSystem.stat(logPath);
				if (stat.size > 10 * 1024 * 1024) { // 10MB
					// Keep old log as backup
					if (FileSystem.exists(appDir+"log.txt.old"))
						FileSystem.deleteFile(appDir+"log.txt.old");
					FileSystem.rename(logPath, appDir+"log.txt.old");
					trace("Log rotated: log.txt -> log.txt.old");
				}
			}

			var timestamp = Date.now().toString();
			var logLine = '[$timestamp] [$level] $msg\n';

			// Append mode - much more efficient than reading entire file
			var output = sys.io.File.append(logPath, false);
			output.writeString(logLine);
			output.close();
		} catch (e:Dynamic) {
			trace("ERROR: Failed to write to log: " + e);
		}
	}

	function initializeMetricsLog()
	{
		try {
			var metricsPath = appDir+"metrics.csv";
			if (!FileSystem.exists(metricsPath)) {
				// Create CSV header
				var header = "timestamp,uptime_sec,threads,active_jobs,memory_mb,cpu_percent,file_handles\n";
				File.saveContent(metricsPath, header);
			}
		} catch (e:Dynamic) {
			trace("Failed to initialize metrics log: " + e);
		}
	}

	function logResourceMetrics()
	{
		try {
			// Get AsyncHttp thread count
			var threadCount = com.akifox.asynchttp.AsyncHttp.getThreadCount();

			// Get active jobs count
			var activeJobsCount = (jobTracker != null) ? jobTracker.getActiveJobsCount() : 0;

			// Get memory and CPU usage
			var memoryMB:Float = 0;
			var cpuPercent:Float = 0;
			var fileHandles:Int = 0;

			try {
				// Get PID
				var proc = new Process("sh", ["-c", "echo $$"]);
				var pidStr = StringTools.trim(proc.stdout.readAll().toString());
				proc.close();

				// Get memory (RSS) and CPU
				var psProc = new Process("ps", ["-p", pidStr, "-o", "rss=,%cpu=", "--no-headers"]);
				var psOutput = StringTools.trim(psProc.stdout.readAll().toString());
				psProc.close();

				var parts = psOutput.split(" ");
				var filteredParts = [];
				for (p in parts) {
					var trimmed = StringTools.trim(p);
					if (trimmed != "") filteredParts.push(trimmed);
				}

				if (filteredParts.length >= 2) {
					var memKB = Std.parseFloat(filteredParts[0]);
					if (!Math.isNaN(memKB)) memoryMB = memKB / 1024.0;

					var cpu = Std.parseFloat(filteredParts[1]);
					if (!Math.isNaN(cpu)) cpuPercent = cpu;
				}

				// Get file handle count
				try {
					var lsofProc = new Process("sh", ["-c", 'lsof -p $pidStr 2>/dev/null | wc -l']);
					var lsofOutput = StringTools.trim(lsofProc.stdout.readAll().toString());
					lsofProc.close();
					var handles = Std.parseInt(lsofOutput);
					if (handles != null) fileHandles = handles - 1; // Subtract header line
				} catch (e:Dynamic) {
					fileHandles = 0;
				}
			} catch (e:Dynamic) {
				trace("Failed to get system metrics: " + e);
			}

			// Calculate uptime
			var uptime = Math.round(Timer.stamp() - startTime);

			// Write to CSV (no rotation)
			var metricsPath = appDir+"metrics.csv";
			var timestamp = Date.now().toString();
			var csvLine = '$timestamp,$uptime,$threadCount,$activeJobsCount,${Math.round(memoryMB*10)/10},$cpuPercent,$fileHandles\n';

			var output = sys.io.File.append(metricsPath, false);
			output.writeString(csvLine);
			output.close();

			// Also log to main log with warnings
			var metrics = '[METRICS] uptime=${uptime}s threads=$threadCount jobs=$activeJobsCount mem=${Math.round(memoryMB)}MB cpu=$cpuPercent% files=$fileHandles';

			if (threadCount > 20) {
				writeToLog(metrics + " | WARNING: Thread count exceeds 20!", "WARN");
			} else if (activeJobsCount > 10) {
				writeToLog(metrics + " | WARNING: Active jobs exceed 10!", "WARN");
			} else if (memoryMB > 100) {
				writeToLog(metrics + " | WARNING: Memory usage exceeds 100MB!", "WARN");
			} else if (cpuPercent > 80) {
				writeToLog(metrics + " | WARNING: CPU usage exceeds 80%!", "WARN");
			} else {
				writeToLog(metrics, "INFO");
			}
		} catch (e:Dynamic) {
			writeToLog("Failed to collect resource metrics: " + e, "ERROR");
		}
	}

	static public function rebootLocalMachine()
	{
		Sys.command("sudo reboot");
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

	static function processLocalCallback(callbackCmd:String)
	{
		switch (callbackCmd.toLowerCase())
		{
			case "reboot": 
				rebootLocalMachine();

			default:
				
		}
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

	static function onPingClientResponse(response:HttpResponse2)
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

	// Add a cleanup method and call it periodically
	function cleanupResources():Void
	{
		if (debug)
		{
			trace("Performing periodic resource cleanup");
		}
		
		// Force garbage collection
		// #if cpp
		// cpp.vm.Gc.run(true);
		// #end
		
		// Recreate HTTP clients
		httpPingRelayRequest = new HttpRequest2({
			url: kontentumLink + restPingRelay + "/" + apiKey,
			callback: onHttpResponse, 
			callbackError: onHttpError,
			async:httpAsync
		});
		httpPingRelayRequest.timeout = 1;//Std.int(Math.floor(pingTime-1.0));
	}


	/////////////////////////////////////////////////////////////////////////////////////

}

typedef PingResponse =
{
	var clients			: Array<PingClient>;
	var all_clients		: Array<PingClient>;
	var schedules		: Array<ScheduleItem>;
	var ping			: Float;
	var timestamp		: String;
	var success			: Bool;
	var callback		: String;
	var url_jobs		: Array<UrlJob>;
}

typedef UrlJob =
{
	var body			: String; 
	var reference		: String; 
	var url				: String; 
	var method			: String;
	var header			: String;
	var content_type	: String;
}

typedef PingClient =
{
	var exhibit_id		: Int; 
	var app_id			: Int; 
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
	
	static public function query(ip:String,?onQueryComplete:(status:Int)->Void,?onQueryFailed:(err:String)->Void)
	{
		var p = new Process(pjLinkPath,[ip, ProjectorCommand.query]);
		var response:String = "";

		if (KontentumNC.debug)
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
			if (response=="POWR=0")
			{
				if (onQueryComplete!=null)
					onQueryComplete(0);
			}
			else if (response=="POWR=1")
			{
				if (onQueryComplete!=null)
					onQueryComplete(1);
			}
			else if (response=="POWR=2")
			{
				if (onQueryComplete!=null)
					onQueryComplete(2);
			}
			else if (response=="POWR=3")
			{
				if (onQueryComplete!=null)
					onQueryComplete(3);
			}
			else if (response=="POWR=4")
			{
				if (onQueryComplete!=null)
					onQueryComplete(4);
			}
			else 
				if (onQueryFailed!=null)
					onQueryFailed(response);

			// if  (KontentumNC.debug)
				// trace("response : "+response);
		}
		
	}

	static public function sendKontentumCallback(pi:PingClient, state:Int)
	{
		var cbStr:String = StringTools.urlEncode('pjlink:${pi.id}')+'/'+StringTools.urlEncode('$state;${pi.ip}');

		var projectorCallbackRequest = new HttpRequest2({url:KontentumNC.kontentumLink + KontentumNC.i.restRelayCallback+"/"+cbStr, callback: onProjectorCallbackResponse, callbackError:onProjectorCallbackError, async:KontentumNC.httpAsync});
		projectorCallbackRequest.timeout = 1;//Std.int(MathUtils.clamp(KontentumNC.i.pingTime-1, 1, 30));
		projectorCallbackRequest.method = "GET";
		if (KontentumNC.debug) trace('Sending callback pjlink:${pi.id} ${projectorCallbackRequest.url} callback with data : $cbStr');
		projectorCallbackRequest.send();
	}

	static function onProjectorCallbackResponse(response:HttpResponse2)
	{
		if (KontentumNC.debug) trace('Projector callback ok : ${response.request.url} : ${response.status} : ${response.content}');
	}

	static function onProjectorCallbackError(response:HttpResponse2)
	{
		if (KontentumNC.debug) trace('Projector callback error : ${response.request.url} : ${response.status} : ${response.content}');
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
