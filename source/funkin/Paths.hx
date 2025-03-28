package funkin;

import haxe.io.Bytes;
import openfl.utils.ByteArray;
import haxe.ds.StringMap;
import funkin.data.LocalizationMap;
import funkin.data.WeekData;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.media.Sound;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;
import EReg;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

//// idgaf about libraries

class Paths
{
	inline public static var IMAGE_EXT = "png";
	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	public static final HSCRIPT_EXTENSIONS:Array<String> = ["hscript", "hxs", "hx"];
	public static final LUA_EXTENSIONS:Array<String> = ["lua"];
	public static final SCRIPT_EXTENSIONS:Array<String> = [
		"hscript",
		"hxs",
		"hx",
		#if LUA_ALLOWED "lua" #end]; // TODo: initialize this by combining the top 2 vars ^


	public static function getFileWithExtensions(scriptPath:String, extensions:Array<String>) {
		for (fileExt in extensions) {
			var baseFile:String = '$scriptPath.$fileExt';
			for (file in [#if MODS_ALLOWED Paths.modFolders(baseFile), #end Paths.getPreloadPath(baseFile)]) {
				if (Paths.exists(file))
					return file;
			}
		}

		return null;
	}

	public static function isHScript(file:String){
		for(ext in Paths.HSCRIPT_EXTENSIONS)
			if(file.endsWith('.$ext'))
				return true;
		
		return false;
	}
	public inline static function getHScriptPath(scriptPath:String)
	{
		#if HSCRIPT_ALLOWED
		return getFileWithExtensions(scriptPath, Paths.HSCRIPT_EXTENSIONS);
		#else
		return null;
		#end
	}

	public inline static function getLuaPath(scriptPath:String) {
		#if LUA_ALLOWED
		return getFileWithExtensions(scriptPath, Paths.LUA_EXTENSIONS);
		#else
		return null;
		#end
	}

	public static var localTrackedAssets:Array<String> = [];
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyIntro.$SOUND_EXT',
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'content/global/music/freakyIntro.$SOUND_EXT',
		'content/global/music/freakyMenu.$SOUND_EXT',
		'content/global/music/breakfast.$SOUND_EXT',
		'assets/images/Garlic-Bread-PNG-Images.$IMAGE_EXT'
	];

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function init() {
		#if html5
		HTML5Paths.initPaths();
		#end

		#if MODS_ALLOWED
		Paths.pushGlobalContent();
		Paths.getModDirectories();
		#end
	}

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null)
				{
					Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);

					// trace('cleared $key');
				}
			}
		}
		// run the garbage collector for good measure lmfao
		openfl.system.System.gc();
	}

	/** removeBitmap(FlxSprite.graphic.key); **/
	public static function removeBitmap(key:String)
	{
		var obj = currentTrackedAssets.get(key);
		if (obj != null) @:privateAccess {
			localTrackedAssets.remove(key);

			Assets.cache.removeBitmapData(key);
			FlxG.bitmap._cache.remove(key);
			obj.destroy();
			currentTrackedAssets.remove(key);
			
			//trace('removed $key');
			//return true;
		}

		//trace('did not remove $key');
		//return false;
	}

	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key => obj in FlxG.bitmap._cache) {
			if (obj != null && !currentTrackedAssets.exists(key)) {
				// trace('cleared $key');
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key => obj in currentTrackedSounds) {
			if (obj != null && !localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
				Assets.cache.removeSound(key);
				currentTrackedSounds.remove(key);
			}
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets.resize(0);
	}

	public static function getPath(key:String, ignoreMods:Bool = false):String
	{
		#if MODS_ALLOWED
		if (ignoreMods != true) {
			var modPath:String = Paths.modFolders(key);
			if (Paths.exists(modPath)) return modPath;
		}
		#end
		return Paths.getPreloadPath(key);
	}

	public static function getPath2(key:String, ignoreMods:Bool = false):String
	{
		return Paths.getPreloadPath(key, 'mobilee');	
	}

	public static function _getPath(key:String, ignoreMods:Bool = false):Null<String>
	{
		var path:String;

		#if MODS_ALLOWED
		if (ignoreMods != true) {
			path = Paths.modFolders(key);
			if (Paths.exists(path)) return path;
		}
		#end

		path = Paths.getPreloadPath(key);
		return Paths.exists(path) ? path : null;
	}

	inline public static function getPreloadPath(file:String = '', library:String = '')
	{
                if (library.startsWith("mobilee")) {
	            return file;
                } else {
	            return 'assets/$file';
                }
	}

	/*
	inline static public function txt(key:String):String
		return 'data/$key.txt';

	inline static public function png(key:String):String
		return 'images/$key.png';

	inline static public function xml(key:String):String
		return 'images/$key.xml';

	inline static public function songJson(key:String):String
		return 'songs/$key.json';

	inline static public function shaderFragment(key:String):String
		return 'shaders/$key.frag';

	inline static public function shaderVertex(key:String):String
		return 'shaders/$key.vert';
	*/

	inline static public function font(key:String)
	{
		return getPath('fonts/$key');
	}

	static public function video(key:String, ignoreMods:Bool = false):String
	{
		return getPath('videos/$key.$VIDEO_EXT', ignoreMods);
	}

	static public function getShaderFragment(name:String):Null<String>
	{
		return _getPath('shaders/$name.frag');
	}
	
	static public function getShaderVertex(name:String):Null<String>
	{
		return _getPath('shaders/$name.vert');
	}

	inline static public function sound(key:String, ?library:String):Null<Sound>
	{
		return returnSound('sounds', key, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Null<Sound>
	{
		return returnSound('music', key, library);
	}

	inline static public function track(song:String, track:String):Null<Sound>
	{
		return returnSound('songs', '${formatToSongPath(song)}/$track');
	}

	inline static public function voices(song:String):Null<Sound>
	{
		return track(song, "Voices");
	}

	inline static public function inst(song:String):Null<Sound>
	{
		return track(song, "Inst");
	}

	inline static public function lua(key:String, ?library:String)
	{
		for (ext in Paths.LUA_EXTENSIONS) {
			var r = getPreloadPath('$key.$ext');
			if (Paths.exists(r))
				return r;
		}
		return null;
	}

	inline static public function withoutEndingSlash(path:String)
		return path.endsWith("/") ? path.substr(0, -1) : path;

	inline static public function exists(path:String, ?type:AssetType):Bool {
		#if sys 
		return FileSystem.exists(path);
		#else
		return Assets.exists(path, type);
		#end
	}

	inline static public function cleanPath(path:String):String {
		// Separate the directory from the file name using the last "/"
		var lastSlash = path.lastIndexOf("/");
		var dir:String = "";
		var filePart:String = "";
		if (lastSlash != -1) {
			dir = path.substring(0, lastSlash);
			filePart = path.substring(lastSlash + 1);
		} else {
			filePart = path;
		}
		
		// Split the file name by "."
		var parts = filePart.split(".");
		var cleanedFile:String = '';
		
		if (parts.length == 1) {
			// No dot in the file name; nothing to clean.
			cleanedFile = filePart;
		} else if (parts[parts.length - 1] == "hscript" && parts.length >= 2) {
			// If the extension is "hx", join the last two segments.
			cleanedFile = parts[parts.length - 2] + ".hscript";
		} else {
			// Otherwise, use just the last segment.
			cleanedFile = parts[parts.length - 1];
		}
		
		// Reassemble the path (if there is a directory)
		if (dir != "") {
			return dir + "/" + cleanedFile;
		}
		return cleanedFile;
	}

	inline static public function getContent(path:String):Null<String> {
		#if sys
		return FileSystem.exists(path) ? File.getContent(path) : null;
		#else
		return Assets.exists(path) ? Assets.getText(path) : null;
		#end
	}
	inline static public function getBytes(path:String):Null<haxe.io.Bytes> {
		#if sys
		return FileSystem.exists(path) ? File.getBytes(path) : null;
		#else
		return Assets.exists(path) ? Assets.getBytes(path) : null;
		#end
	}
	inline static public function isDirectory(path:String):Bool {
		#if sys
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
                #if desktop return HTML5Paths.isDirectory(path); #end
		#end
	}
	inline static public function getDirectoryFileList(path:String):Array<String> {
		#if sys
		return !isDirectory(path) ? [] : FileSystem.readDirectory(path);
		#else
		#if desktop return HTML5Paths.getDirectoryFileList(path); #end
		#end
	}

	inline public static function getText(path:String):Null<String> {
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end

		if (Assets.exists(path))
			return Assets.getText(path);

		return null;
	}
	inline public static function getBitmapData(path:String):Null<BitmapData> {
		#if sys
		if (FileSystem.exists(path))
			return BitmapData.fromFile(path);
		#end

		if (Assets.exists(path, IMAGE))
			return Assets.getBitmapData(path);

		return null;
	}
	inline public static function getSound(path:String):Null<Sound> {
		#if sys
		if (FileSystem.exists(path))
			return Sound.fromFile(path);
		#end

		if (Assets.exists(path))
			return Assets.getSound(path);

		return null;
	}
	static public function getJson(path:String):Null<Dynamic>
	{
		var ret:Null<Dynamic> = null;
		try{
			var raw = Paths.getContent(path);
			if (raw != null)
				ret = haxe.Json.parse(raw);
		}catch(e){
			haxe.Log.trace('$path: $e', null);
		}

		return ret;
	}
	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var xmlPath = getPath('images/$key.xml');
		return FlxAtlasFrames.fromSparrow(
			image(key, library),
			Paths.exists(xmlPath) ? Paths.getContent(xmlPath) : xmlPath
		);
	}

	inline static public function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var txtPath:String = getPath('images/$key.txt');
		return FlxAtlasFrames.fromSpriteSheetPacker(
			image(key, library),
			exists(txtPath) ? getContent(txtPath) : txtPath
		);
	}

	inline static public function txt(key:String, ?library:String)
		return _getPath('$key.txt');

	/** returns a FlxRuntimeShader but with file names lol **/ 
	public static function getShader(fragFile:String = null, vertFile:String = null, version:Int = 120):FlxRuntimeShader
	{
		//weird code lol so much random
        #if mobile
		var optionShit:Array<String> = CoolUtil.coolTextFile(Paths.txt("shaders/ignore"));
		for (i in 0...optionShit.length) {
			if (fragFile == optionShit[i] || vertFile == optionShit[i]) {
				if (fragFile.contains('-android') || vertFile.contains('-android')) {
					if (exists(getShaderFragment(fragFile) + '-android') || exists(getShaderVertex(vertFile) + '-android')) {
						try {
						var fragPath:Null<String> = fragFile==null ? null : getShaderFragment(fragFile) + '-android';
						var vertPath:Null<String> = vertFile==null ? null : getShaderVertex(vertFile) + '-android';
						return new FlxRuntimeShader(
							fragFile==null ? null : Paths.getContent(fragPath), 
							vertFile==null ? null : Paths.getContent(vertPath),
							//version
						);
						} catch(e:Dynamic){
							trace("Shader compilation error:" + e.message);
						}
					}
					else 
					{
						return null;
					}
				}
				return null;
			}
		}
        #end

		try{
			var fragPath:Null<String> = fragFile==null ? null : getShaderFragment(fragFile);
			var vertPath:Null<String> = vertFile==null ? null : getShaderVertex(vertFile);

			return new FlxRuntimeShader(
				fragFile==null ? null : Paths.getContent(fragPath), 
				vertFile==null ? null : Paths.getContent(vertPath),
				//version
			);
		}catch(e:Dynamic){
			trace("Shader compilation error:" + e.message);
		}

		return null;		
	}

	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(path:String, func:haxe.Constraints.Function):Bool
	{
		#if sys
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
			return false;
		
		for (name in FileSystem.readDirectory(path))
			func(name);

		return true;
		
		#else
		#if desktop return HTML5Paths.iterateDirectory(path, func); #end
		#end
	}

	inline static public function fileExists(key:String, ?type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		return Paths.exists(getPath(key, ignoreMods));
	}

	/** Returns the contents of a file as a string. **/
	inline public static function text(key:String, ?ignoreMods:Bool = false):Null<String>
		return getContent(getPath(key, ignoreMods));

	inline public static function bytes(key:String, ?ignoreMods:Bool = false):Null<Bytes>
		return getBytes(getPath(key, ignoreMods));

	private static final hideChars = ['.','!','?','%','"',",","'"];
	private static final invalidChars = [' ','#','>','<',':',';','\\','~','&'];

	inline static public function formatToSongPath(path:String) {
		var finalPath = "";

		for (idx in 0...path.length)
		{
			var char = path.charAt(idx);   

			if (hideChars.contains(char))
				continue;
			else if (invalidChars.contains(char))
				finalPath += "-";
			else 
				finalPath += char;
		}

		return finalPath.toLowerCase();
	}

	public static function getGraphic(path:String, cache:Bool = true, gpu:Bool = false):Null<FlxGraphic>
	{
		var newGraphic:FlxGraphic = cache ? currentTrackedAssets.get(path) : null;
		if (newGraphic == null) {
			var bitmap:BitmapData = getBitmapData(path);
			if (bitmap == null) return null;

			if (gpu) {
				var texture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
				texture.uploadFromBitmapData(bitmap);
				bitmap.image.data = null;
				bitmap.dispose();
				bitmap = BitmapData.fromTexture(texture);
			}

			newGraphic = FlxGraphic.fromBitmapData(bitmap, false, path, cache);
			newGraphic.persist = true;
			newGraphic.destroyOnNoUse = false;

			if (cache) {
				localTrackedAssets.push(path);
				currentTrackedAssets.set(path, newGraphic);
			}
		}

		return newGraphic;
	}

	inline public static function cacheGraphic(path:String):Null<FlxGraphic>
		return getGraphic(path, true);

	inline public static function imagePath(key:String):String
		return getPath('images/$key.$IMAGE_EXT');

	inline public static function imagePath2(key:String):String
		return getPath2('mobilee/images/$key.$IMAGE_EXT');

	inline public static function imageExists(key:String):Bool
		return Paths.exists(imagePath(key));

	inline static public function image(key:String, ?library:String):Null<FlxGraphic>
		return returnGraphic(key, library);

	public static function returnGraphic(key:String, ?library:String):Null<FlxGraphic>
	{
                if (library == 'mobilee') {
		    var path:String = imagePath2(key);

		    if (currentTrackedAssets.exists(path)) {
			    if (!localTrackedAssets.contains(path)) 
				    localTrackedAssets.push(path);

			    return currentTrackedAssets.get(path);
		    }

		    var graphic = getGraphic(path);
		    if (graphic==null && Main.showDebugTraces)
			    trace('bitmap "$key" => "$path" returned null.');

		    return graphic;
                }
		var path:String = imagePath(key);

		if (currentTrackedAssets.exists(path)) {
			if (!localTrackedAssets.contains(path)) 
				localTrackedAssets.push(path);

			return currentTrackedAssets.get(path);
		}

		var graphic = getGraphic(path);
		if (graphic==null && Main.showDebugTraces)
			trace('bitmap "$key" => "$path" returned null.');

		return graphic;
	}

	inline public static function soundPath(path:String, key:String, ?library:String)
	{
		return getPath('$path/$key.$SOUND_EXT');
	}

	public static function returnSound(path:String, key:String, ?library:String)
	{
		var gottenPath:String = soundPath(path, key, library);
	
		if (currentTrackedSounds.exists(gottenPath)) {
			if (!localTrackedAssets.contains(gottenPath))
				localTrackedAssets.push(gottenPath);

			return currentTrackedSounds.get(gottenPath);
		}
		
		var sound = getSound(gottenPath);
		if (sound != null) {
			currentTrackedSounds.set(gottenPath, sound);
	
			if (!localTrackedAssets.contains(gottenPath))
				localTrackedAssets.push(gottenPath);	
			
			return sound;
		}
		
		if (Main.showDebugTraces)
			trace('sound $path, $key => $gottenPath returned null');
		
		return null;
	}

	/** Return the contents of a file, parsed as a JSON. **/
	static public function json(key:String, ?ignoreMods:Bool = false):Null<Dynamic>
	{
		var rawJSON:Null<String> = text(key, ignoreMods);
		if (rawJSON == null) 
			return null;
		
		try{
			return Json.parse(rawJSON);
		}catch(e){
			haxe.Log.trace('$key: $e', null);
		}
		
		return null;
	}

	////	
	public static var currentModDirectory(default, set):String = '';
	static function set_currentModDirectory(v:String){
		if (currentModDirectory == v)
			return currentModDirectory;

		if (!contentMetadata.exists(v))
			return currentModDirectory = v;

		if (!contentDirectories.exists(v))return currentModDirectory = '';
		
		if (contentMetadata.get(v).dependencies != null)
			dependencies = contentMetadata.get(v).dependencies;
		else
			dependencies = [];

		//trace('set to $v with ${dependencies.length} dependencies');

		return currentModDirectory = v;
	}

	// TODO: Write all of this to be not shit and use just like a generic load order thing
	public static var globalContent:Array<String> = [];
	public static var dependencies:Array<String> = [];
	public static var preLoadContent:Array<String> = [];
	public static var postLoadContent:Array<String> = [];

	public static var modsList:Array<String> = [];
	public static var contentDirectories:Map<String, String> = [];
	public static var contentMetadata:Map<String, ContentMetadata> = [];

	#if MODS_ALLOWED
	inline static public function mods(key:String)
		return #if mobile Sys.getCwd() + #end 'content/$key';

	inline static public function getGlobalContent(){
		return globalContent;
	}

	static public function pushGlobalContent(){
		globalContent = [];

		for (mod => json in getContentMetadata())
		{
			if (Reflect.field(json, "runsGlobally") == true) 
				globalContent.push(mod);
		}

		return globalContent;
	}
	
	static public function modFolders(key:String, ignoreGlobal:Bool = false)
	{
		var shitToCheck:Array<String> = [];
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			shitToCheck.push(Paths.currentModDirectory);

		for (mod in dependencies)
			shitToCheck.push(mod);

		if (shitToCheck.length > 0) {
			for (shit in shitToCheck){
				var fileToCheck:String = contentDirectories.get(shit) + '/' + key;
				if (exists(fileToCheck))
					return fileToCheck;
			        #if (linux || android)
			        else
			        {
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			        }
			        #end
			}
		}

		if (ignoreGlobal != true) {
			for (mod in getGlobalContent()) {
				var fileToCheck:String = contentDirectories.get(mod) + '/' + key;
				if (exists(fileToCheck))
					return fileToCheck;
			        #if (linux || android)
			        else
			        {
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			        }
			        #end
			}
		}
		return mods(key);
	}

	// I might end up making this just return an array of loaded mods and require you to press a refresh button to reload content lol
	// mainly for optimization reasons, so its not going through the entire content folder every single time
	public static function updateContentLists()
	{
		var list:Array<String> = modsList = [];
		contentMetadata.clear();

		contentDirectories.clear();
		contentDirectories.set('', 'content');

		iterateDirectory('content', (folderName) -> {
			var folderPath = #if mobile Sys.getCwd() + #end 'content/$folderName';

			if (isDirectory(folderPath) && !list.contains(folderName))
			{
				list.push(folderName);
				contentDirectories.set(folderName, folderPath);

				var rawJson:Null<String> = Paths.getContent('$folderPath/metadata.json');
				if (rawJson != null && rawJson.length > 0) {
					var data:Dynamic = Json.parse(rawJson);
					contentMetadata.set(folderName, updateContentMetadataStructure(data));
					return;
				}

				#if PE_MOD_COMPATIBILITY
				var psychModMetadata = getPsychModMetadata(folderName);
				if (psychModMetadata != null)
					contentMetadata.set(folderName, psychModMetadata);
				#end
			}
		});
	}

	#if PE_MOD_COMPATIBILITY
	static function getPsychModMetadata(folderName:String):ContentMetadata {
		var packJson:String = Paths.mods('$folderName/pack.json');
		var packJson:Null<String> = Paths.getContent(packJson);
		var packJson:Dynamic = (packJson == null) ? packJson : Json.parse(packJson);

		var sowy:ContentMetadata = {
			runsGlobally: (packJson != null) && Reflect.field(packJson, 'runsGlobally') == true, 
			weeks: [],
			freeplaySongs: []
		}

		for (psychWeek in WeekData.getPsychModWeeks(folderName))
			WeekData.addPsychWeek(sowy, psychWeek);

		return sowy;
	}
	#end
	
	inline static function updateContentMetadataStructure(data:Dynamic):ContentMetadata
	{
		if (Reflect.field(data, "weeks") != null)
			return data; // You are valid :)

		var chapters:Dynamic = Reflect.field(data, "chapters");
		if (chapters != null) { // TGT
			Reflect.setField(data, "weeks", chapters);
			Reflect.deleteField(data, "chapters");
			return data;
		}else { // Lets assume it's an old TGT metadata
			return {weeks: [data]};
		}
	}

	static public function getModDirectories():Array<String> 
	{
		updateContentLists();
		return modsList;
	}

	static public function getContentMetadata():Map<String, ContentMetadata>
	{
		updateContentLists();
		return contentMetadata;
	}
	#end

	#if (android || linux)
	static function findFile(key:String):String {
		var targetParts:Array<String> = key.replace('\\', '/').split('/');
		if (targetParts.length == 0) return null;

		var baseDir:String = targetParts.shift();
		var searchDirs:Array<String> = [
			mods(Paths.currentModDirectory + '/' + baseDir),
			mods(baseDir)
		];

		for (part in targetParts) {
			if (part == '') continue;

			var nextDir:String = findNodeInDirs(searchDirs, part);
			if (nextDir == null) {
				return null;
			}

			searchDirs = [nextDir];
		}

		return searchDirs[0];
	}

	static function findNodeInDirs(dirs:Array<String>, key:String):String {
		for (dir in dirs) {
			var node:String = findNode(dir, key);
			if (node != null) {
				return dir + '/' + node;
			}
		}
		return null;
	}

	static function findNode(dir:String, key:String):String {
		try {
			var allFiles:Array<String> = Paths.readDirectory(dir);
			var fileMap:Map<String, String> = new Map();

			for (file in allFiles) {
				fileMap.set(file.toLowerCase(), file);
			}

			return fileMap.get(key.toLowerCase());
		} catch (e:Dynamic) {
			return null;
		}
	}
	#end

	public static function readDirectory(directory:String):Array<String>
	{
		#if MODS_ALLOWED
		return FileSystem.readDirectory(directory);
		#else
		var dirs:Array<String> = [];
		for (dir in Assets.list().filter(folder -> folder.startsWith(directory)))
		{
			@:privateAccess
			for (library in lime.utils.Assets.libraries.keys())
			{
				if (library != 'default' && Assets.exists('$library:$dir') && (!dirs.contains('$library:$dir') || !dirs.contains(dir)))
					dirs.push('$library:$dir');
				else if (Assets.exists(dir) && !dirs.contains(dir))
					dirs.push(dir);
			}
		}
		return dirs.map(dir -> dir.substr(dir.lastIndexOf("/") + 1));
		#end
	}

	inline static public function getFolders(dir:String, ?modsOnly:Bool = false){
		#if !MODS_ALLOWED
		return [Paths.getPreloadPath('$dir/')];
		
		#else
		var foldersToCheck:Array<String> = [
			Paths.mods(Paths.currentModDirectory + '/$dir/'),
			Paths.mods('$dir/'),
		];

		if(!modsOnly)
			foldersToCheck.push(Paths.getPreloadPath('$dir/'));
		
		for(mod in dependencies)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		for(mod in preLoadContent)foldersToCheck.push(Paths.mods('$mod/$dir/'));
		for(mod in getGlobalContent())foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));
		for(mod in postLoadContent)foldersToCheck.insert(0, Paths.mods('$mod/$dir/'));


		return foldersToCheck;
		#end
	}
	
	public static function loadRandomMod()
	{
		Paths.currentModDirectory = '';
	}

	//// String stuff, should maybe move this to a diff class¿¿¿
	public static var locale(default, set):String;
	
	private static final currentStrings:Map<String, String> = [];
	
	@:noCompletion static function set_locale(l:String){
		if (l != locale) {
			locale = l;
			getAllStrings();
		}
		return locale;
	}

	public static function getAllStrings():Void {
		currentStrings.clear();
		// trace("refreshing strings");

		var checkFiles = ['lang/$locale.txt', 'lang/$locale.lang', "lang/en.txt", "strings.txt"]; 
		for (filePath in Paths.getFolders("data")) {
			for (fileName in checkFiles) {
				var path:String = filePath + fileName;
				if (!Paths.exists(path)) continue;
				
				var file = LocalizationMap.fromFile(path);
				for (k => v in file) {
					if (!currentStrings.exists(k))
						currentStrings.set(k, v);
				}
			}
		}
	}

	public static inline function hasString(key:String):Bool
		return currentStrings.exists(key);

	public static inline function _getString(key:String):Null<String>
		return currentStrings.get(key);

	public static inline function getString(key:String, ?defaultValue:String):String
		return hasString(key) ? _getString(key) : (defaultValue==null ? key : defaultValue);
}

#if desktop
class HTML5Paths {
	#if !sys 
	// Directory => Array with file/sub-directory names
	static var dirMap = new Map<String, Array<String>>();

	public static function initPaths(){	
		dirMap.clear();
		dirMap.set("", []);

		for (path in Assets.list())
		{
			//trace("WORKING WITH PATH:", path);

			var file:String = path.split("/").pop();
			var parent:String = path.substr(0, path.length - (file.length + 1)); // + 1 to remove the ending slash

			var parentTree = parent.split("/");
			for (totality in 1...parentTree.length+1)
			{
				var totality = parentTree.length - totality;
				var dirPathSplit = [for (i in 0...totality+1) {parentTree[i];}];
				var dirPath = dirPathSplit.join("/");
				
				if (!dirMap.exists(dirPath)){
					dirMap.set(dirPath, []);
					//trace("reg folder", dirPath, "from", path);
				//}else{
					//trace("did NOT reg folder", dirPath, "from", path);
				}
			}
			
			dirMap.get(parent).push(file);
			//trace("END");
		}
		
		////
		for (path => dir in dirMap)
		{
			var name:String = path.split("/").pop();
			var parent:String = path.substr(0, path.length - (name.length + 1)); // + 1 to remove the ending slash

			if (dirMap.exists(parent)){
				var parentDir = dirMap.get(parent);
				if (!parentDir.contains(name)){
					parentDir.push(name);
				}
			}
		}

		// trace(dirMap["assets/songs"]);

		return dirMap;
	}

	inline static public function withoutEndingSlash(path:String)
		return path.endsWith("/") ? path.substr(0, -1) : path;

	inline static public function isDirectory(path:String):Bool {
		return dirMap.exists(withoutEndingSlash(path));
	}

	inline static public function getDirectoryFileList(path:String):Array<String> {
		var dir:String = withoutEndingSlash(path);
		return !dirMap.exists(dir) ? [] : [for (i in dirMap.get(dir)) i];
	}

	/** 
		Iterates through a directory and calls a function with the name of each file contained within it
		Returns true if the directory was a valid folder and false if not.
	**/
	inline static public function iterateDirectory(path:String, Func:haxe.Constraints.Function)
	{
		var dir:String = withoutEndingSlash(path);

		if (!dirMap.exists(dir)){
			trace('Directory $dir does not exist?');
			return false;
		}

		for (i in dirMap.get(dir))
			Func(i);
		
		return true;
	}
	#end
}
#end

typedef FreeplaySongMetadata = {
	/**
		Name of the song to be played
	**/
	var name:String;

	/**
		Category ID for the song to be placed into (main, side, remix)
	**/
	var category:String;

	/**
		Displayed name of the song.
		Does not have to be the same as name.
	**/
	@:optional var displayName:String;
}

typedef FreeplayCategoryMetadata = {
	/**
		Displayed Name of the category
		This is used to show the category in the freeplay list
	**/
	var name:String;

	/**
		ID of the category
		This gets used when adding songs to the category
		(Defaults are main, side and remix)
	**/
	var id:String;
}

typedef ContentMetadata = {
	/**
		Weeks to be added to the story mode
	**/
	var weeks:Array<funkin.data.WeekData.WeekMetadata>;
	
	/**
		Content that will load before this content.
	**/
	@:optional var dependencies:Array<String>;

	/**
		Stages that can appear in the title menu
	**/
	@:optional var titleStages:Array<String>;

	/**
		Songs to be placed into the freeplay menu
	**/
	@:optional var freeplaySongs:Array<FreeplaySongMetadata>;

	/**
		Categories to be placed into the freeplay menu
	**/
	@:optional var freeplayCategories:Array<FreeplayCategoryMetadata>;
	
	/**
		If this is specified, then songs don't have to be added to freeplaySongs to have them appear
		As anything in the songs folder will appear in this category instead
	**/
	@:optional var defaultCategory:String;
	/**
		This mod will always run, regardless of whether it's currently being played or not.
		(Custom HUDs, etc, will find this useful, as you can have stuff run across every song without adding to the global folder)
	**/
	@:optional var runsGlobally:Bool;
}