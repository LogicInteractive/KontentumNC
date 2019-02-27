package;

import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import haxe.Timer;
import haxe.io.Bytes;
import sys.io.Process;
import sys.net.Address;
import sys.net.Host;
import sys.net.UdpSocket;

/**
 * ...
 * @author Tommy S.
 */

typedef TargetMachineInfo = 
{
	var ip		: String;
	var mac		: String;
}
 
class KontentumNC 
{
	//===================================================================================
	// Main 
	//-----------------------------------------------------------------------------------
	
	var kontentumLink		: String				= "https://kontentum.link";
	var restPingRelay		: String				= "/rest/pingRelay/";
	var apiKey				: String				= "0c8238b9c3349ec6d8dbd4b25939d705";
	var udpSocket			: UdpSocket;
	var b					: Bytes;
	var address				: Address;
	var tm					: TargetMachineInfo;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main() { new KontentumNC(); }
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public function new()
	{
		tm =
		{
			ip	: "192.168.1.10", 
			mac	: "98-F2-B3-E7-CC-1E"
		};
		
		//var tm:TargetMachine = { ip:"127.0.0.1", mac:"08-6A-0A-83-FA-15" };
		udpSocket = new UdpSocket();
		var clientHost:Host = new Host(Host.localhost());
		
		address= new Address();
		address.host = new Host(tm.ip).ip;
		address.port = 9; //Hardcoded for WOL
		b = createMagicPacket(tm.mac);
		
		var httpRequest = new HttpRequest( { url:kontentumLink+restPingRelay+apiKey, callback:onHttpResponse });		
		
		var t = new Timer(1000);
		t.run = function ()
		{
			var h = httpRequest.clone();
			h.send();
		}
	}
	
	function onHttpResponse(response:HttpResponse)
	{
		//sendUDP();
		if (response.isOK)
		{
			trace(response.content);
			//if (response.content != null)
				//onPingData(response);
			//else
				//onPingCorruptData(response);
		}
		//else
			//onPingError(response);
	}  
	
	function sendUDP()
	{
		udpSocket.sendTo(b, 0, b.length, address);	
		trace("WOL packet sent to | " + tm.ip + " | " + tm.mac);
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
	
}

