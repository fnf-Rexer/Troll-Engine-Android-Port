package;

import flixel.FlxG;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.system.Capabilities;
import openfl.events.Event;
import lime.app.Application;
#if mobile
import mobile.CopyState;
import mobile.StorageUtil;
#end

import funkin.*;

#if desktop
import funkin.api.Github;
#end
import funkin.data.SemanticVersion;

using StringTools;

#if discord_rpc
import funkin.api.Discord.DiscordClient;
#end

#if CRASH_HANDLER
import haxe.CallStack;
import openfl.events.UncaughtErrorEvent;

#if sys
import sys.io.File;
#end

#if (windows && cpp)
@:cppFileCode('#include <windows.h>')
#end
#end

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = StartupState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static var volumeChangedEvent:lime.app.Event<Float->Void> = new lime.app.Event<Float->Void>();
	public static var engineVersion:String = '0.2.0'; // Used for autoupdating n stuff
	public static var betaVersion(get, default):String = 'rc.1'; // beta version, make blank if not on a beta version, otherwise do it based on semantic versioning (alpha.1, beta.1, rc.1, etc)
	public static var beta:Bool = betaVersion.trim() != '';

        #if desktop
	public static var UserAgent:String = 'TrollEngine/${Main.engineVersion}'; // used for http requests. if you end up forking the engine and making your own then make sure to change this!!
	public static var githubRepo:RepoInfo = Github.getCompiledRepoInfo();
	public static var downloadBetas:Bool = beta;
	public static var outOfDate:Bool = false;
	public static var recentRelease:Release;
        #end

	public static var showDebugTraces:Bool = true;

	static function get_betaVersion()
		return beta ? betaVersion : "0";

    @:isVar
    public static var semanticVersion(get, null):SemanticVersion = '';
	static function get_semanticVersion()
		return '$engineVersion${beta ? '-$betaVersion' : ""}';

	@:isVar
	public static var displayedVersion(get, null):String = '';
	static function get_displayedVersion()
		return 'v${semanticVersion}';
	    
	////
	public static var fpsVar:FPS;

	#if desktop
	//public static var bread:Bread;
	#end
	
	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end

                #if android 
		CrashHandler.init();
                #end

		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	public static function setScaleMode(scale:String){
		switch(scale){
			default:
				Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
			case 'EXACT_FIT':
				Lib.current.stage.scaleMode = StageScaleMode.EXACT_FIT;
			case 'NO_BORDER':
				Lib.current.stage.scaleMode = StageScaleMode.NO_BORDER;
			case 'SHOW_ALL':
				Lib.current.stage.scaleMode = StageScaleMode.SHOW_ALL;
		}
	}

	private function setupGame():Void
	{
                #if desktop
		final screenWidth = Capabilities.screenResolutionX;
		final screenHeight = Capabilities.screenResolutionY;
                #end

                #if mobile
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight; 
                #end

		//// Readjust the game size for smaller screens
		if (zoom == -1)
		{
                        #if desktop
			if (!(screenWidth > gameWidth || screenHeight > gameWidth)){
				var ratioX:Float = screenWidth / gameWidth;
				var ratioY:Float = screenHeight / gameHeight;
				
				zoom = Math.min(ratioX, ratioY);
				gameWidth = Math.ceil(screenWidth / zoom);
				gameHeight = Math.ceil(screenHeight / zoom);
			}
                        #end

                        #if android
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
				
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
                        #end
		}

		#if android
		gameWidth = 1280;
		gameHeight = 720;
		zoom = 1;
		#end
	
		////		
		var troll = false;

		#if sys
		for (arg in Sys.args()){
			switch(arg){
				case "troll":
					troll = true;

				case "songselect":
					StartupState.nextState = funkin.states.SongSelectState;

				case "debug":
					funkin.states.PlayState.chartingMode = true;
				
				case "showdebugtraces":
					Main.showDebugTraces = true;
			}
		}
		#end

		#if tgt
		if (troll){
			initialState = funkin.tgt.SinnerState;
			skipSplash = true;
		}else
		#end
		{
                        #if desktop
			//// Readjust the window size for larger screens 
			var scaleFactor:Int = Math.ceil((screenWidth > screenHeight) ? (screenHeight / gameHeight) : (screenWidth / gameWidth));
			if (scaleFactor > 1) scaleFactor--;
			
			final windowWidth:Int = scaleFactor * gameWidth;
			final windowHeight:Int = scaleFactor * gameHeight;

			Application.current.window.resize(
				windowWidth, 
				windowHeight
			);
			Application.current.window.move(
				Std.int((screenWidth - windowWidth) / 2),
				Std.int((screenHeight - windowHeight) / 2)
			);
                        #end

			////
			@:privateAccess
			FlxG.initSave();
			startFullscreen = FlxG.save.data.fullscreen;
		}
		
		addChild(new FNFGame(gameWidth, gameHeight, initialState, #if(flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));

		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = false;

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		fpsVar.visible = false;
		addChild(fpsVar);

		#if desktop
		//bread = new Bread();
		//bread.visible = false;
		//addChild(bread);
		#end

		#if CRASH_HANDLER
		// Original code was made by sqirra-rng, big props to them!!!
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR, 
			(event:UncaughtErrorEvent) -> onCrash(event.error)
		);


		#if cpp
		// Thank you EliteMasterEric, very cool!
		untyped __global__.__hxcpp_set_critical_error_handler(onCrash);
		#end
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		lime.system.System.allowScreenTimeout = ClientPrefs.ScreenSaver;
		#if android
		FlxG.android.preventDefaultKeys = [BACK]; 
		#end
		#end
	}

	public static function getTime():Float {
		#if flash
		return flash.Lib.getTimer();
		#elseif ((js && !nodejs) || electron)
		return js.Browser.window.performance.now();
		#elseif sys
		return Sys.time() * 1000;
		#elseif (lime_cffi && !macro)
		@:privateAccess
		return cast lime._internal.backend.native.NativeCFFI.lime_system_get_timer();
		#elseif cpp
		return untyped __global__.__time_stamp() * 1000;
		#else
		return 0;
		#end
	}

	
	#if CRASH_HANDLER
	function onCrash(errorName:String):Void
	{
		////
		var ogTrace = haxe.Log.trace;
		haxe.Log.trace = (msg, ?pos)->{
			ogTrace(msg, null);
		}

		////
		trace("\nCall stack starts below");

		var callstack:String = "";

		for (stackItem in CallStack.exceptionStack(true))
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					callstack += '$file:$line\n';
				default:
			}
		}

		callstack += '\n$errorName';

		trace('\n$callstack\n');

		#if (windows && cpp)
		windows_showErrorMsgBox(callstack, errorName);
		#else
		Application.current.window.alert(callstack, errorName);
		#end

		#if discord_rpc
		DiscordClient.shutdown(true);
		#end

		#if sys
		File.saveContent("crash.txt", callstack);
		Sys.exit(1);
		#end
	}

	#if (windows && cpp)
	@:functionCode('MessageBox(NULL, message, title, MB_ICONERROR | MB_OK);')
	function windows_showErrorMsgBox(message:String, title:String){}
	#end

	#end
}