package;

import haxe.Timer;

class OfflineTracker
{
	var owner			: KontentumNC;
	var lastPingTime	: Float;
	var timer			: Timer;

	public function new(owner:KontentumNC)
	{
		this.owner = owner;
		gotPing();
		timer = new Timer(1000*60);
		timer.run = check;
	}

	public function gotPing()
	{
		lastPingTime = Timer.stamp();
	}

	function check()
	{
		var currentPingTime = Timer.stamp();
		var timeSinceLastPing = currentPingTime-lastPingTime;
		// trace("Time since last ping: ",timeSinceLastPing);
		var halfHourSec:Float = 60*30;
		if (timeSinceLastPing>halfHourSec)
			KontentumNC.rebootLocalMachine();
	}
}