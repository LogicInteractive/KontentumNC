package;

import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.macro.Expr.Error;
import no.logic.uix.utils.ObjUtils;
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

class KontentumNC 
{
	//===================================================================================
	// Main 
	//-----------------------------------------------------------------------------------
	
	var kontentumLink		: String				= "https://kontentum.link";
	var restPingRelay		: String				= "/rest/pingRelay/";
	var apiKey				: String				= "0c8238b9c3349ec6d8dbd4b25939d705";
	
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
			
		udpSocket = new UdpSocket();
	
		httpPingRequest = new HttpRequest( { url:kontentumLink+restPingRelay+apiKey, callback:onHttpResponse });		
		
		pingTimer = new Timer(1000);
		pingTimer.run = onPing;
	}
	
	function onPing() 
	{
		httpPingRequest.clone().send();
	}
	
	/////////////////////////////////////////////////////////////////////////////////////

	function onHttpResponse(response:HttpResponse)
	{
		if (response.isOK)
		{
			trace(response.content);
			//if (response.content != null)
				//onPingData(response);
			//else
				//onPingCorruptData(response);
				
			sendMagicPacket("127.0.0.1", "08:6A:0A:83:FA:15");
		}
		//else
			//onPingError(response);
	}  
	
	function sendMagicPacket(ip:String, macAdr:String)
	{
		var packet:Bytes = createMagicPacket(macAdr);
		
		var adr = new Address();
		adr.host = new Host(ip).ip;
		adr.port = 9; //Hardcoded for WOL

		udpSocket.sendTo(packet, 0, packet.length, adr);	
		trace("WOL packet sent to " + ip + " : " + macAdr);
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
	
	function createMagicPacket(macAddr:String):Bytes 
	{
		if (macAddr == null)
			return null;
			
		macAddr.split(":").join("-");
		
		var macAddrSt:Array<String> = macAddr.split("-");
		var macAddrHex:Array<Int> = [];
		for (i in 0...macAddrSt.length) 
		{
			macAddrHex.push(Std.parseInt("0x"+macAddrSt[i]));
		}
		
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

