package funkin;

import funkin.scripts.Globals;

#if SCRIPTABLE_STATES
import funkin.states.MusicBeatState;
import funkin.scripts.FunkinHScript.HScriptedState;
#end

class FNFGame extends FlxGame
{
	public function new(gameWidth = 0, gameHeight = 0, ?initialState:Class<FlxState>, updateFramerate = 60, drawFramerate = 60, skipSplash = false, startFullscreen = false)
	{
		super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = flixel.system.ui.DefaultFlxSoundTray;
	}

	override function switchState():Void
	{
		#if SCRIPTABLE_STATES
		if (_requestedState is MusicBeatState)
		{
			var state:MusicBeatState = cast _requestedState;
			if (state.canBeScripted)
			{
				var className = Type.getClassName(Type.getClass(_requestedState));
                                var stateName = className.substr(className.lastIndexOf(".")+1);
				for (filePath in Paths.getFolders("states"))
				{
					var fileName = 'override/$stateName.hscript';
                                        trace(filePath + fileName);
					if (Paths.exists(filePath + fileName))
					{
						_requestedState.destroy();
						_requestedState = HScriptedState.fromFile(fileName);
						trace(fileName);
						return super.switchState();
					}
				}
			}
		}
		#end
		trace(Paths.cleanPath('assets/fuck/shit.bruh.PauseShit.hx'));	
		Globals.variables.clear();
		super.switchState();
	}
}