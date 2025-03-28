package funkin.scripts;

import funkin.scripts.Util.ModchartSprite;
#if USING_FLXANIMATE
import funkin.objects.FlxAnimateCompat; // vscode stfu
#end
import funkin.scripts.FunkinScript.ScriptType;
import funkin.objects.IndependentVideoSprite;
import funkin.scripts.*;
import funkin.scripts.Globals.*;

import funkin.states.PlayState;
import funkin.states.MusicBeatState;
import funkin.states.MusicBeatSubstate;

import funkin.input.PlayerSettings;
import funkin.api.Windows;

import flixel.FlxG;
import flixel.math.FlxPoint;

import lime.app.Application;
import haxe.Constraints.Function;

import hscript.*;

using StringTools;

class FunkinHScript extends FunkinScript
{
	public static final parser:Parser = {
		var parser = new Parser();

		parser.allowMetadata = true;
		parser.allowJSON = true;
		parser.allowTypes = true;

		parser.preprocesorValues = funkin.macros.Sowy.getDefines();
		parser.preprocesorValues.set("TROLL_ENGINE", Main.engineVersion);

		parser;
	};

	public static var errored:Bool = false;
	
	public static final defaultVars:Map<String, Dynamic> = new Map<String, Dynamic>();

	public static function init() // BRITISH
	{
		
	}

	inline public static function parseString(script:String, ?name:String = "Script")
	{
		parser.line = 1;
		return parser.parseString(script, name);
	}

	inline public static function parseFile(file:String, ?name:String)
		return parseString(Paths.getContent(file), (name == null ? file : name));

	public static function blankScript(?name, ?additionalVars)
	{
		return new FunkinHScript(null, name, additionalVars, false);
	}

	/** No exception catching or display */
	public static function _fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
		return new FunkinHScript(parseString(script, name), name, additionalVars, doCreateCall);

	// safe ver
	public static function fromString(script:String, ?name:String = "Script", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true):FunkinHScript
	{
		try {
			errored = false;
			return _fromString(script, name, additionalVars, doCreateCall);
		}
		catch (e:haxe.Exception) {
			errored = true;
			var errMsg = 'Error parsing hscript! ' #if hscriptPos + '$name:' + parser.line + ', ' #end + e.message;
			trace(errMsg);

			#if desktop
			Application.current.window.alert(errMsg, "Error on haxe script!");
			#end
		}

		return new FunkinHScript(null, name, additionalVars, doCreateCall);
	}

	public static function fromFile(file:String, ?name:String, ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true):FunkinHScript
	{
		name = (name == null ? file : name);

		try {
			errored = false;
			return _fromString(Paths.getContent(file), name, additionalVars, doCreateCall);
		}
		catch(e:haxe.Exception) {
			errored = true;
			var msg = "Error parsing hscript! " + e.message;
			trace(msg);

			#if desktop
			var title = "Error on haxe script!";

			#if (cpp && windows)
			if (Windows.msgBox(msg, title, RETRYCANCEL | ERROR) == RETRY)
				return fromFile(file, name, additionalVars, doCreateCall);
			#else
			Application.current.window.alert(msg, title);
			#end
			#end
		}

		return new FunkinHScript(null, name, additionalVars, doCreateCall);
	}

	private static inline function trim_redundant_error_trace(message:String, posInfo:haxe.PosInfos):String
	{
		if (message.startsWith(posInfo.fileName)) {
			var to_remove = posInfo.fileName + ":" + posInfo.lineNumber + ": ";
			message = message.substr(to_remove.length); 
		}

		return message;
	}

	////
	private var interpreter(default, null):Interp = new Interp();

	public function new(?parsed:Expr, ?name:String = "HScript", ?additionalVars:Map<String, Any>, ?doCreateCall:Bool = true)
	{
		super(name, ScriptType.HSCRIPT);

		set("Std", Std);
		set("Type", Type);
		set("Reflect", Reflect);
		set("Math", Math);
		set("StringTools", StringTools);
		set("Main", Main);

		set("StringMap", haxe.ds.StringMap);
		set("ObjectMap", haxe.ds.ObjectMap);
		set("EnumValueMap", haxe.ds.EnumValueMap);
		set("IntMap", haxe.ds.IntMap);

		set("Date", Date);
		set("DateTools", DateTools);
		
		set("getClass", Type.resolveClass);
		set("getEnum", Type.resolveEnum);
		
		#if NMV_MOD_COMPATIBILITY
		set("addHaxeLibrary", function(c:String, ?p:String){
			// Dumb hardcoded whatever idc!!!

			if (c == 'KUTValueHandler')
				return;

			if (c == 'HitSingleMenu'){
				importClass("funkin.states.FreeplayState");
				return;
			}

			if (p == 'meta.states')
				p = 'funkin.states';

			if (p == 'gameObjects')
				p = 'funkin.objects';

			if (p == 'gameObjects.shader')
				p = 'funkin.objects.shaders';

			if (p == 'meta.data')
				p = 'funkin.data';

			if (p == 'meta.data.scripts')
				p = 'funkin.scripts';


			if(p != null)
				importClass('$p.$c');
			else
				importClass(c);
		});
		#end
		set("importClass", importClass);
		set("importEnum", importEnum);

		set("print", print);
		
		set("script", this);
		set("global", Globals.variables);
		set("FunkinHScript", FunkinHScript);

		setDefaultVars();
		setFlixelVars();
		setVideoVars();
		setFNFVars();

		for (variable => arg in defaultVars)
			set(variable, arg);

		if (additionalVars != null)
		{
			for (key => value in additionalVars)
				set(key, value);
		}

		if (parsed != null){
			run(parsed);
			
			if (doCreateCall)
				call('onCreate');
		}
	}

	/**
		Helper function
		Sets a bunch of basic variables for the script depending on the state
	**/
	override function setDefaultVars() {
		super.setDefaultVars();

		var currentState = flixel.FlxG.state;
		
		set("state", currentState);
		set("game", currentState);
		
		if (currentState is PlayState){
			var currentState:PlayState = cast currentState;
			var debugPrint:Function = Reflect.makeVarArgs(function(toPrint) {
				currentState.addTextToDebug('$scriptName: ${toPrint.join(', ')}');
			});

			set("getInstance", getInstance);
			set("debugPrint", debugPrint);

		}else{
			set("getInstance", @:privateAccess FlxG.get_state);
			set("debugPrint", get("trace"));
			
		}
	}

	private function setFlixelVars() 
	{
		set("FlxG", FlxG);
		#if NMV_MOD_COMPATIBILITY
		set("FlxSprite", ModchartSprite);
		#else
		set("FlxSprite", FlxSprite);
		#end
		set("FlxCamera", FlxCamera);
		set("FlxSound", FlxSound);
		set("FlxMath", flixel.math.FlxMath);
		set("FlxTimer", flixel.util.FlxTimer);
		set("FlxTween", flixel.tweens.FlxTween);
		set("FlxEase", flixel.tweens.FlxEase);
		set("FlxGroup", flixel.group.FlxGroup);
		set("FlxSave", flixel.util.FlxSave); // should probably give it 1 save instead of giving it FlxSave
		set("FlxBar", flixel.ui.FlxBar);
		set('FlxTrail', flixel.addons.effects.FlxTrail);
		set('ComicReader', funkin.tgt.gallery.ComicsMenuState.ComicReader);

		set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
		set('FlxObject', flixel.FlxObject);
		set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		set('FlxInputText', flixel.addons.ui.FlxInputText);
		set('FlxTypeText', flixel.addons.text.FlxTypeText);

		set("FlxAxes", Wrappers.FlxAxes);
		set("FlxBarFillDirection", flixel.ui.FlxBar.FlxBarFillDirection);
		set("FlxText", flixel.text.FlxText);
		set("FlxTextBorderStyle", flixel.text.FlxText.FlxTextBorderStyle);
		set("FlxCameraFollowStyle", flixel.FlxCamera.FlxCameraFollowStyle);

		set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);

		set("FlxParticle", flixel.effects.particles.FlxParticle);
		set("FlxTypedEmitter", flixel.effects.particles.FlxEmitter.FlxTypedEmitter);
		set("FlxSkewedSprite", flixel.addons.effects.FlxSkewedSprite);

                set("TouchPad", mobile.TouchPad);
                set("Hitbox", mobile.Hitbox);
                set("MobileData", mobile.MobileData);
                set("IMobileControls", mobile.IMobileControls);
                set("FlxDestroyUtil", flixel.util.FlxDestroyUtil);

		// Abstracts
		set("BlendMode", Wrappers.BlendMode);

		set("FlxColor", Wrappers.SowyColor);
		set("FlxPoint", {
			get: FlxPoint.get,
			weak: FlxPoint.weak
		});
		set("FlxTextAlign", Wrappers.FlxTextAlign);
		set("FlxTweenType", Wrappers.FlxTweenType); 
		#if USING_FLXANIMATE
		set("FlxAnimate", FlxAnimateCompat);
		#end
	}

	private function setVideoVars() {
		// TODO: create a compatibility wrapper for the various versions
		// (so you can use any version of hxcodec and use the same versions)

		#if !VIDEOS_ALLOWED
		set("hxcodec", "0");
		set("MP4Handler", null);
		set("MP4Sprite", null);
		#else
		#if (hxCodec >= "3.0.0")
		set("hxcodec", "3.0.0");
		set("MP4Handler", hxcodec.flixel.FlxVideo);
		set("MP4Sprite", hxcodec.flixel.FlxVideoSprite); // idk how hxcodec 3.0.0 works :clueless:
		#elseif (hxCodec >= "2.6.1")
		set("hxcodec", "2.6.1");
		set("MP4Handler", hxcodec.VideoHandler);
		set("MP4Sprite", hxcodec.VideoSprite);
		#elseif (hxCodec == "2.6.0")
		set("hxcodec", "2.6.0");
		set("MP4Handler", VideoHandler);
		set("MP4Sprite", VideoSprite);
		#elseif (hxCodec)
		set("hxcodec", "1.0.0");
		set("MP4Handler", vlc.MP4Handler);
		set("MP4Sprite", vlc.MP4Sprite);
		#else
		set("hxcodec", "0");
		#end
		#if (hxvlc)
		set("hxvlc", "1.0.0");
		set("MP4Handler", hxvlc.flixel.FlxVideo);
		set("MP4Sprite", hxvlc.flixel.FlxVideoSprite);
		#else
		set("hxvlc", "0");
		#end
		#end	
		set("VideoSprite", IndependentVideoSprite); // Should use this in future !

	}
	
	public static function StateSwitchScript(path, isshit) {
		var scriptName = Paths.getHScriptPath(path);
		trace(scriptName);
	
		var script:FunkinHScript = createHScript(scriptName, scriptName, isshit);
	
		var state = new HScriptedState(script);
		MusicBeatState.switchState(state);
	}

	public static function createHScript(path:String, ?scriptName:String, ?ignoreCreateCall:Bool = false):FunkinHScript
	{
		var split = path.split("/"); 
		var modName:String = split[0] == "content" ? split[1] : 'assets';
		var script = FunkinHScript.fromFile(path, scriptName, [
				"modName" => modName
		], ignoreCreateCall != true);
		return script;
	}

	private function setFNFVars() {
		// FNF-specific things
		set("controls", PlayerSettings.player1.controls);
		set("get_controls", () -> return PlayerSettings.player1.controls);
		
		set("Paths", funkin.Paths);
		set("Conductor", funkin.Conductor);
		set("ClientPrefs", funkin.ClientPrefs);
		set("CoolUtil", funkin.CoolUtil);

		set("newShader", Paths.getShader);

		set("PlayState", PlayState);
		set("MusicBeatState", MusicBeatState);
		set("MusicBeatSubstate", MusicBeatSubstate);
		set("GameOverSubstate", funkin.states.GameOverSubstate);
		set("Song", funkin.data.Song);
		set("BGSprite", funkin.objects.BGSprite);
		set("RatingSprite", funkin.objects.RatingGroup.RatingSprite);
		set("SongMetadata", funkin.data.Song.SongMetadata);

		set("Note", funkin.objects.Note);
		set("NoteObject", funkin.objects.NoteObject);
		set("NoteSplash", funkin.objects.NoteSplash);
		set("StrumNote", funkin.objects.StrumNote);
		set("PlayField", funkin.objects.playfields.PlayField);
		set("NoteField", funkin.objects.playfields.NoteField);

		set("ProxyField", funkin.objects.proxies.ProxyField);
		set("ProxySprite", funkin.objects.proxies.ProxySprite);
		set("AltBGSprite", funkin.objects.BGSprite.AltBGSprite);

		set("FlxSprite3D", funkin.objects.FlxSprite3D);

		set("AttachedSprite", funkin.objects.AttachedSprite);
		set("AttachedText", funkin.objects.AttachedText);

		set("Character", funkin.objects.Character);
		set("HealthIcon", funkin.objects.hud.HealthIcon);

		set("Wife3", funkin.data.JudgmentManager.Wife3);
		set("PBot", funkin.data.JudgmentManager.PBot);
		set("JudgmentManager", funkin.data.JudgmentManager);
		set("Judgement", Wrappers.Judgment);

		set("ModManager", funkin.modchart.ModManager);
		set("Modifier", funkin.modchart.Modifier);
		set("SubModifier", funkin.modchart.SubModifier);
		set("NoteModifier", funkin.modchart.NoteModifier);
		set("EventTimeline", funkin.modchart.EventTimeline);
		set("StepCallbackEvent", funkin.modchart.events.StepCallbackEvent);
		set("CallbackEvent", funkin.modchart.events.CallbackEvent);
		set("ModEvent", funkin.modchart.events.ModEvent);
		set("EaseEvent", funkin.modchart.events.EaseEvent);
		set("SetEvent", funkin.modchart.events.SetEvent);

		set("HScriptedHUD", funkin.objects.hud.HScriptedHUD);
		set("HScriptModifier", funkin.modchart.HScriptModifier);

		set("HScriptedState", HScriptedState);
		set("HScriptedSubState", HScriptedSubState);
		set("HScriptState", HScriptState);
		set("HScriptSubState", HScriptSubState);
	} 

	function importClass(className:String)
	{
		// importClass("flixel.util.FlxSort") should give you FlxSort.byValues, etc
		// whereas importClass("scripts.Globals.*") should give you Function_Stop, Function_Continue, etc
		// i would LIKE to do like.. flixel.util.* but idk if I can get everything in a namespace
		var classSplit:Array<String> = className.split(".");
		var daClassName = classSplit[classSplit.length - 1]; // last one

		if (daClassName == '*')
		{
			var daClass = Type.resolveClass(className);

			while (classSplit.length > 0 && daClass == null)
			{
				daClassName = classSplit.pop();
				daClass = Type.resolveClass(classSplit.join("."));
				if (daClass != null)
					break;
			}
			if (daClass != null)
			{
				for (field in Reflect.fields(daClass))
					set(field, Reflect.field(daClass, field));
			}
			else
			{
				FlxG.log.error('Could not import class $className');
			}
		}
		else
		{
			set(daClassName, Type.resolveClass(className));
		}
	}

	function importEnum(enumName:String)
	{
		// same as importClass, but for enums
		// and it cant have enum.*;
		var splitted:Array<String> = enumName.split(".");
		var daEnum = Type.resolveEnum(enumName);
		if (daEnum != null)
			set(splitted.pop(), daEnum);
	}

	/**
	 * Parses and executes string code
	 */
	public function executeCode(source:String):Dynamic
		return run(parseString(source, scriptName));
	
	public function run(parsed:Expr) {
		var returnValue:Dynamic = null;
		try {
			trace('Running haxe script: $scriptName');
			returnValue = interpreter.execute(parsed);
			errored = false;
		}
		catch (e:haxe.Exception)
		{
			errored = true;
			var posInfo = interpreter.posInfos();
			var message = trim_redundant_error_trace(e.message, posInfo);
			
			haxe.Log.trace(message, posInfo);
		}
		return returnValue;
	}

	public function stop()
	{
		//trace('stopping $scriptName');

		// idk if there's really a stop function or anythin for hscript so
		if (interpreter != null && interpreter.variables != null)
			interpreter.variables.clear();

		interpreter = null;
	}

	public function get(varName:String):Dynamic
	{
		return (interpreter == null) ? null : interpreter.variables.get(varName);
	}

	public function set(varName:String, value:Dynamic):Void
	{
		if (interpreter != null)
			interpreter.variables.set(varName, value);
	}

	public function exists(varName:String):Bool
	{
		return interpreter != null && interpreter.variables.exists(varName);
	}

	public function call(func:String, ?parameters:Array<Dynamic>, ?extraVars:Map<String, Dynamic>):Dynamic
	{
		var returnValue:Dynamic = executeFunc(func, parameters, null, extraVars);
		
		return returnValue == null ? Function_Continue : returnValue;
	}

	/**
	 * Calls a function within the script
	**/
	public function executeFunc(funcName:String, ?parameters:Array<Dynamic>, ?parentObject:Any, ?extraVars:Map<String, Dynamic>):Dynamic
	{
		var daFunc:Function = get(funcName);

		if (!Reflect.isFunction(daFunc))
			return null;

		if (parameters == null)
			parameters = [];

		if (parentObject != null){
			if (extraVars == null) extraVars = [];
			extraVars.set("this", parentObject);
		}

		var prevVals:Map<String, Dynamic> = null;

		if (extraVars != null) {
			prevVals = [];

			for (name => value in extraVars) {
				prevVals.set(name, get(name));
				set(name, value);
			}
		}

		var returnVal:Dynamic = null;
		try {
			returnVal = Reflect.callMethod(parentObject, daFunc, parameters);
			errored = false;
		}
		catch (e:haxe.Exception)
		{
			errored = true;
			var posInfo = interpreter.posInfos();
			var message = trim_redundant_error_trace(e.message, posInfo);

			print('$scriptName: Error executing $funcName(${parameters.join(', ')}): ' + haxe.Log.formatOutput(message, posInfo));
		}

		if (prevVals != null) {
			for (name => value in prevVals)
				set(name, value);
		}

		return returnVal;
	}
}

class HScriptState extends MusicBeatState
{
	public var scripty:HScriptedState;

	public function new(path:String, ?ignoreCreate:Bool = false) {
		super();

		var scriptName = Paths.getHScriptPath(path);
		if (script != null) return;

		script = createHScript(scriptName, scriptName, ignoreCreate);
        scripty = new HScriptedState(script, ignoreCreate); 
	}

	public function createHScript(path:String, ?scriptName:String, ?ignoreCreateCall:Bool = false):FunkinHScript
	{
		var split = path.split("/");
		var modName:String = split[0] == "content" ? split[1] : 'assets';
		var script = FunkinHScript.fromFile(path, scriptName, [
			"modName" => modName
		], ignoreCreateCall != true);
		return script;
	}
}

// tbh i'd *LIKE* to use a macro for this but im lazy lol

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class HScriptedState extends MusicBeatState
{
	public var stateScript:FunkinHScript;
	public var scriptPath:Null<String> = null;

	public function new(?script:FunkinHScript, ?doCreateCall:Bool = true)
	{
		super(false); // false because the whole point of this state is its scripted lol

		if (script == null)
			this.stateScript = FunkinHScript.blankScript();
		else
			this.stateScript = script;

		// some shortcuts
		stateScript.set("this", this);
		stateScript.set("add", this.add);
		stateScript.set("remove", this.remove);
		stateScript.set("insert", this.insert);
		stateScript.set("members", this.members);
		// TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState

		stateScript.set("get_controls", () -> return PlayerSettings.player1.controls);
		stateScript.set("controls", PlayerSettings.player1.controls);

		if (doCreateCall != false)
			stateScript.call("onLoad");
	}

	public static function fromString(str:String, ?doCreateCall:Bool = true)
	{
		return new HScriptedState(FunkinHScript.fromString(str, "HScriptedState", null, doCreateCall));
	}

	public static function fromPath(scriptPath:String, ?doCreateCall:Bool = true)
	{
		var script:Null<FunkinHScript> = null;

		if (scriptPath != null) {
			script = FunkinHScript.fromFile(scriptPath, scriptPath, variables, false);
		} else {
			trace('State script file "$scriptPath" not found!');
		}

		var state = new HScriptedState(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		if (!fileName.endsWith(".hscript"))
			fileName += ".hscript";

		for (folderPath in Paths.getFolders("states"))
		{
			var filePath = folderPath + fileName;

			if (Paths.exists(filePath)){
				scriptPath = filePath;
				break;
			}
		}

		return fromPath(scriptPath);
	}

	override function create()
	{
		// UPDATE: realised I should be using the "on" prefix just so if a script needs to call an internal function it doesnt cause issues
		// (Also need to figure out how to give the super to the classes incase that's needed in the on[function] funcs though honestly thats what the post functions are for)
		// I'd love to modify HScript to add override specifically for troll engine hscript
		// THSCript...

		// onCreate is used when the script is created so lol
		if (stateScript.call("onStateCreate", []) == Globals.Function_Stop) // idk why you'd return stop on create on a HScriptedState but.. sure
			return;

		super.create();
		stateScript.call("onStateCreatePost");
	}

	override function update(e)
	{
		#if debug
		if (FlxG.keys.justPressed.F7)
			if (scriptPath != null && !FlxG.keys.pressed.CONTROL)
				FlxG.switchState(new HScriptedState(scriptPath));
			else
				FlxG.switchState(new FreeplayState());
		#end

		if (stateScript.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		stateScript.call("onUpdatePost", [e]);
	}

	override function beatHit()
	{
		stateScript.call("onBeatHit");
		super.beatHit();
	}

	override function stepHit()
	{
		stateScript.call("onStepHit");
		super.stepHit();
	}

	override function closeSubState()
	{
		if (stateScript.call("onCloseSubState") == Globals.Function_Stop)
			return;

		super.closeSubState();

		stateScript.call("onCloseSubStatePost");
	}

	override function onFocus()
	{
		if (stateScript.call("onOnFocus") == Globals.Function_Stop)
			return;

		super.onFocus();

		stateScript.call("onOnFocusPost");
	}

	override function onFocusLost()
	{
		if (stateScript.call("onOnFocusLost") == Globals.Function_Stop)
			return;

		super.onFocusLost();

		stateScript.call("onOnFocusLostPost");
	}

	override function onResize(w:Int, h:Int)
	{
		if (stateScript.call("onOnResize", [w, h]) == Globals.Function_Stop)
			return;

		super.onResize(w, h);

		stateScript.call("onOnResizePost", [w, h]);
	}

	override function openSubState(subState:FlxSubState)
	{
		if (stateScript.call("onOpenSubState", [subState]) == Globals.Function_Stop)
			return;

		super.openSubState(subState);

		stateScript.call("onOpenSubStatePost", [subState]);
	}

	override function resetSubState()
	{
		if (stateScript.call("onResetSubState") == Globals.Function_Stop)
			return;

		super.resetSubState();

		stateScript.call("onResetSubStatePost");
	}

	override function startOutro(onOutroFinished:() -> Void)
	{
		final currentState = FlxG.state;

		if (stateScript.call("onStartOutro", [onOutroFinished]) == Globals.Function_Stop)
			return;

		if (FlxG.state == currentState) // if "onOutroFinished" wasnt called by the func above ^ then call onOutroFinished for it
			onOutroFinished(); // same as super.startOutro(onOutroFinished)

		stateScript.call("onStartOutroPost", []);
	}

	static var switchToDeprecation = false;

	override function switchTo(s:FlxState)
	{
		if (!stateScript.exists("onSwitchTo"))
			return super.switchTo(s);

		if (!switchToDeprecation)
		{
			trace("switchTo is deprecated. Consider using startOutro");
			switchToDeprecation = true;
		}
		if (stateScript.call("onSwitchTo", [s]) == Globals.Function_Stop)
			return false;

		super.switchTo(s);

		stateScript.call("onSwitchToPost", [s]);
		return true;
	}

	override function transitionIn(?onEnter:() -> Void)
	{
		if (stateScript.call("onTransitionIn") == Globals.Function_Stop)
			return;

		super.transitionIn();

		stateScript.call("onTransitionInPost");
	}

	override function transitionOut(?onExit:() -> Void)
	{
		if (stateScript.call("onTransitionOut", [onExit]) == Globals.Function_Stop)
			return;

		super.transitionOut(onExit);

		stateScript.call("onTransitionOutPost", [onExit]);
	}

	override function draw()
	{
		if (stateScript.call("onDraw", []) == Globals.Function_Stop)
			return;

		super.draw();

		stateScript.call("onDrawPost", []);
	}

	override function destroy()
	{
		if (stateScript.call("onDestroy", []) == Globals.Function_Stop)
			return;

		super.destroy();

		stateScript.call("onDestroyPost", []);
	}

	// idk sometimes you wanna override add/remove
	override function add(member:FlxBasic):FlxBasic
	{
		if (stateScript.call("onAdd", [member], []) == Globals.Function_Stop)
			return member;

		super.add(member);

		stateScript.call("onAddPost", [member]);
		return member;
	}

	override function remove(member:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (stateScript.call("onRemove", [member, splice]) == Globals.Function_Stop)
			return member;

		super.remove(member, splice);

		stateScript.call("onRemovePost", [member, splice]);
		return member;
	}

	override function insert(position:Int, member:FlxBasic):FlxBasic
	{
		if (stateScript.call("onInsert", [position, member]) == Globals.Function_Stop)
			return member;

		super.insert(position, member);

		stateScript.call("onInsertPost", [position, member]);

		return member;
	}
}

class HScriptSubState extends MusicBeatSubstate
{
	var scripty:HScriptedState;

	public function new(path:String, ?ignoreCreate:Bool = false) {
		super();

		var scriptName = Paths.getHScriptPath(path);
		if (script != null) return;

		script = createHScript(scriptName, scriptName, ignoreCreate);
        scripty = new HScriptedState(script, ignoreCreate); 
	}

	public function createHScript(path:String, ?scriptName:String, ?ignoreCreateCall:Bool = false):FunkinHScript
	{
		var split = path.split("/");
		var modName:String = split[0] == "content" ? split[1] : 'assets';
		var script = FunkinHScript.fromFile(path, scriptName, [
			"modName" => modName
		], ignoreCreateCall != true);
		return script;
	}
}

@:noScripting // honestly we could prob use the scripting thing to override shit instead
class HScriptedSubState extends MusicBeatSubstate
{
	public var stateScript:FunkinHScript;
	public var scriptPath:Null<String> = null;

	public function new(?script:FunkinHScript, ?doCreateCall:Bool = true)
	{
		super();

		if (script==null)
			this.stateScript = FunkinHScript.blankScript();
		else
			this.stateScript = script;

		// some shortcuts
		stateScript.set("this", this);
		stateScript.set("add", this.add);
		stateScript.set("remove", this.remove);
		stateScript.set("insert", this.insert);
		stateScript.set("members", this.members);
		stateScript.set("close", close);

		// TODO: use a macro to auto-generate code to variables.set all variables/methods of MusicBeatState

		stateScript.set("get_controls", () -> return PlayerSettings.player1.controls);
		stateScript.set("controls", PlayerSettings.player1.controls);

		if (doCreateCall != false)
			stateScript.call("onLoad");
	}

	public static function fromString(str:String, ?doCreateCall:Bool = true)
	{
		return new HScriptedSubState(FunkinHScript.fromString(str, "HScriptedState", null, doCreateCall));
	}

	public static function fromFile(fileName:String, ?doCreateCall:Bool = true)
	{
		var scriptPath:Null<String> = null;

		if (!fileName.endsWith(".hscript"))
			fileName += ".hscript";

		for (folderPath in Paths.getFolders("states"))
		{
			var filePath = folderPath + fileName;

			if (Paths.exists(filePath)){
				scriptPath = filePath;
				break;
			}
		}

		var script:Null<FunkinHScript> = null;

		if (scriptPath != null){
			script = FunkinHScript.fromFile(scriptPath, scriptPath, variables, false);			
		}else{
			trace('Script file "$fileName" not found!');
		}

		var state = new HScriptedSubState(script, doCreateCall);
		state.scriptPath = scriptPath;
		return state;
	}

	override function update(e)
	{
		if (stateScript.call("onUpdate", [e]) == Globals.Function_Stop)
			return;

		super.update(e);

		stateScript.call("onUpdatePost", [e]);
	}

	override function close()
	{
		if (stateScript != null)
			stateScript.call("onClose");

		return super.close();
	}

	override function destroy()
	{
		if (stateScript != null)
		{
			stateScript.call("onDestroy");
			stateScript.stop();
		}
		stateScript = null;

		return super.destroy();
	}
}