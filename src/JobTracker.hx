package;

import HttpRequest2;
import KontentumNC.UrlJob;
import haxe.Json;
import no.logic.uix.utils.MathUtils;

class JobTracker
{
	var currentJobs		: Map<String,{ref:String,url:String,method:String,fingerPrint:String,request:HttpRequest2}> = [];
	var owner			: KontentumNC;

	public function new(owner:KontentumNC)
	{
		this.owner = owner;
	}

	public function getActiveJobsCount():Int
	{
		return Lambda.count(currentJobs);
	}

	public function processUrlJobs(jobs:Array<UrlJob>)
	{
		if (jobs==null || jobs.length==0) return;

		var jobCount = jobs.length;
		var activeCount = getActiveJobsCount();
		KontentumNC.writeToLog('[JobTracker] [JOB_BATCH_RECEIVED] count=$jobCount active_before=$activeCount', "INFO");

		if (activeCount + jobCount > 10) {
			KontentumNC.writeToLog('[JobTracker] [JOB_BATCH_RECEIVED] WARNING: Total jobs will exceed 10! active=$activeCount new=$jobCount', "WARN");
		}

		for (job in jobs)
			executeJob(job);
	}

	function executeJob(job:UrlJob)
	{
		final ref:String = job.reference;
		final method:String = job.method;
		final url:String = job.url;
		final body:String = (job.body!=null && job.body!="") ? StringTools.urlDecode(job.body) : null;
		final header:String = (job.header!=null && job.header!="") ? StringTools.urlDecode(job.header) : null;

		var jobRequest = new HttpRequest2({url:url, callback: onJobResponse, callbackError:onJobError, async:KontentumNC.httpAsync});
		jobRequest.timeout = 1;

		if (method==null || method=="")
			jobRequest.method = "GET";
		else
		{
			jobRequest.method = method.toUpperCase();
			final contentType:String = (job.content_type!=null && job.content_type!="") ? job.content_type : "application/json";
			jobRequest.contentType = contentType;
		}
		if (body!=null && body!="")
			jobRequest.content = body;

		addHeaders(header,jobRequest);

		final fingerprint = jobRequest.fingerprint;

		currentJobs.set(fingerprint,{
			ref:ref,
			url:url,
			method:method,
			fingerPrint:fingerprint,
			request: jobRequest
		});

		var activeCount = getActiveJobsCount();
		KontentumNC.writeToLog('[JobTracker] [JOB_START] ref=$ref fingerprint=$fingerprint method=$method url=$url active_jobs=$activeCount', "INFO");

		jobRequest.send();
	}

	function addHeaders(header:String,jobRequest:HttpRequest2)
	{
		if (header==null || header=="") return;

		try
		{
			var headerData:Dynamic = Json.parse(header);
			if (headerData==null) return;
			for (hname in Reflect.fields(headerData))
			{
				var hvalue = Reflect.field(headerData,hname);
				jobRequest.headers.add(hname,hvalue);
			}
		}
		catch(e:haxe.Exception)
		{
			if (KontentumNC.debug) trace('Error parsing header json : $header');
		}
		// if (jobRequest.method=="GET") return;
		// jobRequest.headers.add("Content-Type","application/json");
	}

	function onJobResponse(response:HttpResponse2)
	{
		var success:Bool = response.status==200;
		var activeCount = getActiveJobsCount();
		KontentumNC.writeToLog('[JobTracker] [JOB_RESPONSE] fingerprint=${response.fingerprint} status=${response.status} time=${response.time}s active_jobs=$activeCount', "INFO");

		sendJobCallback(success, response);
		cleanJob(response.fingerprint);
	}

	function onJobError(response:HttpResponse2)
	{
		var activeCount = getActiveJobsCount();
		KontentumNC.writeToLog('[JobTracker] [JOB_ERROR] fingerprint=${response.fingerprint} status=${response.status} error=${response.error} active_jobs=$activeCount', "ERROR");

		// Don't send callback on error - just clean up
		cleanJob(response.fingerprint);
	}

	function sendJobCallback(success:Bool, response:HttpResponse2)
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
		var jobCallbackRequest = new HttpRequest2({url:KontentumNC.kontentumLink + owner.restRelayCallback+"/"+cbStr, callback: onJobCallbackResponse, callbackError:onJobCallbackError, async:KontentumNC.httpAsync});
		jobCallbackRequest.timeout = Std.int(MathUtils.clamp(owner.pingTime-1, 1, 30));
		jobCallbackRequest.method = "GET";

		KontentumNC.writeToLog('[JobTracker] [JOB_CALLBACK_START] ref=$ref success=$success fingerprint=${jobCallbackRequest.fingerprint}', "INFO");

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

	function onJobCallbackResponse(response:HttpResponse2)
	{
		KontentumNC.writeToLog('[JobTracker] [JOB_CALLBACK_RESPONSE] fingerprint=${response.fingerprint} status=${response.status}', "INFO");
	}

	function onJobCallbackError(response:HttpResponse2)
	{
		KontentumNC.writeToLog('[JobTracker] [JOB_CALLBACK_ERROR] fingerprint=${response.fingerprint} status=${response.status} error=${response.error}', "ERROR");
	}

	function cleanJob(fingerPrint:String)
	{
		if (currentJobs.exists(fingerPrint))
		{
			var j = currentJobs.get(fingerPrint);
			if (j!=null && j.request!=null)
				j.request = null;

			currentJobs.remove(fingerPrint);

			var numJobsRemaining = getActiveJobsCount();
			KontentumNC.writeToLog('[JobTracker] [JOB_CLEANUP] fingerprint=$fingerPrint remaining=$numJobsRemaining', "INFO");
		}
	}

}