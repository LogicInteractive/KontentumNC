package;
import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import haxe.Timer;
import haxe.io.Bytes;
import sys.io.Process;
import sys.net.Address;
import sys.net.Host;
import sys.net.UdpSocket;
//import no.logic.uix.network.udp.UDPConnection;

/**
 * ...
 * @author Tommy S.
 */

typedef TargetMachine = 
{
	var ip		: String;
	var mac		: String;
}
 
class KontentumNC 
{
	//===================================================================================
	// Main 
	//-----------------------------------------------------------------------------------
	
	//var udp				: UDPConnection;
	var udpSocket			: UdpSocket;
	var b					: Bytes;
	var address				: Address;
	var udpSocketz:UdpSocket;
	var hostz:Host;
	var tm:TargetMachine;

	/////////////////////////////////////////////////////////////////////////////////////

	static function main() 
	{
		new KontentumNC();
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	public function new()
	{
		tm = { ip:"192.168.1.10", mac:"98-F2-B3-E7-CC-1E" };
		//var tm:TargetMachine = { ip:"127.0.0.1", mac:"08-6A-0A-83-FA-15" };
		udpSocket = new UdpSocket();
		var clientHost:Host = new Host(Host.localhost());
		//udpSocket.bind(clientHost, 7);
		
		udpSocketz = new UdpSocket();
		hostz = new Host(Host.localhost());
		udpSocketz.bind(hostz, 9331);
		
		
		address= new Address();
		address.host = new Host(tm.ip).ip;
		address.port = 9; //Hardcoded for WOL
		b = createMagicPacket(tm.mac);
		
		var httpRequest = new HttpRequest( { url:"https://kontentum.link/rest/pingClient/233", callback:onHttpResponse });		
		
		var t = new Timer(1000);
		t.run = function ()
		{
			//trace("ping");
			var h = httpRequest.clone();
			h.send();
		}
	}
	
	function onHttpResponse(response:HttpResponse)
	{
		sendUDP();
		//trace("OK!");
		//trace(response.content);
		//if (response.isOK)
		//{
			//if (response.content != null)
				//onPingData(response);
			//else
				//onPingCorruptData(response);
		//}
		//else
			//onPingError(response);
			
			
		//return;

		//var receiveBytes:Bytes = Bytes.alloc(2048);
		//var senderAddress:Address = new Address();
		//while(true) {
		  //udpSocket.waitForRead();
		  //var funk = udpSocketz.readFrom(receiveBytes,0,2048,address);
		  // do something with receiveBytes, but how much is in there?
		  //trace("D:");
		//}			
			
	}  
	
	function sendUDP()
	{
		udpSocket.sendTo(b, 0, b.length, address);	
		trace("WOL packet sent to | " + tm.ip + " | " + tm.mac);
		//trace("MP : "+b.toHex().toUpperCase());
		
		//var a:Array<String> = [];
		//a.push("-i");
		//a.push("192.168.1.10");
		//a.push("-p");
		//a.push("9");
		//a.push("98:F2:B3:E7:CC:1E");
		//
		////Sys.command("wakeonlan", a);
		//
		//new sys.io.Process('wakeonlan', a).close();
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

