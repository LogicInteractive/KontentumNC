package;

import haxe.Timer;

class OfflineTracker
{
	var owner			: KontentumNC;
	var lastPingTime	: Float;

	public function new(owner:KontentumNC)
	{
		this.owner = owner;
		lastPingTime = Timer.stamp();
	}

	public function gotPing()
	{
		var currentPingTime = Timer.stamp();
		var timeSinceLastPing = currentPingTime-lastPingTime;

		var oneHourSec:Float = 60*60;
		if (timeSinceLastPing>oneHourSec)
			KontentumNC.rebootLocalMachine();

		lastPingTime = currentPingTime;
	}
}