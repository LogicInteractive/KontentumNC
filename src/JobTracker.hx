package;

import KontentumNC.UrlJob;
import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import no.logic.uix.utils.MathUtils;

class JobTracker
{
	var currentJobs		: Map<String,{ref:String,url:String,method:String,fingerPrint:String,request:HttpRequest}> = [];
	var owner			: KontentumNC;

	public function new(owner:KontentumNC)
	{
		this.owner = owner;
	}

	public function processUrlJobs(jobs:Array<UrlJob>)
	{
		if (jobs==null || jobs.length==0) return;
		for (job in jobs)
			executeJob(job);
	}

	function executeJob(job:UrlJob)
	{
		final ref = job.reference;
		final method = job.method;
		final url = job.url;

		var jobRequest = new HttpRequest({url:url, callback: onJobResponse, callbackError:onJobError});
		jobRequest.timeout = 20;
		final fingerprint = jobRequest.fingerprint;

		currentJobs.set(fingerprint,{
			ref:ref,
			url:url,
			method:method,
			fingerPrint:fingerprint,
			request: jobRequest
		});

		if (KontentumNC.debug) trace('Job launching : $ref $fingerprint $url');
		jobRequest.send();

	}

	function onJobResponse(response:HttpResponse)
	{
		var success:Bool = response.status==200;
		if (KontentumNC.debug) trace('Job ${response.fingerprint} : response.status : ${response.status}');
		sendJobCallback(success, response);

		if (KontentumNC.debug) trace('Job completed ${response.fingerprint}');
		cleanJob(response.fingerprint);
	}

	function onJobError(response:HttpResponse)
	{
		if (KontentumNC.debug) trace('Job ${response.fingerprint} : response.status : ${response.status}');

		var success:Bool = false;
		sendJobCallback(success, response);

		if (KontentumNC.debug) trace('Job failed ${response.fingerprint}');
		cleanJob(response.fingerprint);
	}

	function sendJobCallback(success:Bool, response:HttpResponse)
	{
		var ref:String = null;
		if (currentJobs.exists(response.fingerprint))
		{
			var j = currentJobs.get(response.fingerprint);
			ref = j.ref;
		}

		var isBinary = response.isBinary;
		var callbackObj = 
		{
			reference:ref,
			success:success,
			response:isBinary?null:response.content
		};

		var cbStr:String = createDataObject(success,ref,Std.string(response.content));
		var jobCallbackRequest = new HttpRequest({url:KontentumNC.kontentumLink + owner.restRelayCallback+"/"+cbStr, callback: onJobCallbackResponse, callbackError:onJobCallbackError});
		jobCallbackRequest.timeout = Std.int(MathUtils.clamp(owner.pingTime-1, 1, 30));
		jobCallbackRequest.method = "GET";
		if (KontentumNC.debug) trace('Sending job ${response.fingerprint} ${jobCallbackRequest.url} callback with data : $cbStr');
		jobCallbackRequest.send();
	}

	function createDataObject(success:Bool,reference:String,response:String):String
	{
		var str = '';
		str+=StringTools.urlEncode(reference);
		str+='/';
		str+=StringTools.urlEncode(response);
		return str;
	}

	function onJobCallbackResponse(response:HttpResponse)
	{
		if (KontentumNC.debug) trace('Job callback ${response.request.url} : ${response.status} : ${response.content}');
	}

	function onJobCallbackError(response:HttpResponse)
	{
		if (KontentumNC.debug) trace('Job callback Error${response.request.url} : ${response.status} : ${response.content}');
	}

	function cleanJob(fingerPrint:String)
	{
		if (currentJobs.exists(fingerPrint))
		{
			var j = currentJobs.get(fingerPrint);
			if (j!=null && j.request!=null)
				j.request = null;

			currentJobs.remove(fingerPrint);

			var numJobsRemaining = Lambda.count(currentJobs);
			if (KontentumNC.debug) trace('Job $fingerPrint cleared. $numJobsRemaining remaining.');
		}
	}

}