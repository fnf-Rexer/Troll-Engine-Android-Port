#if !macro
import flixel.*;
import flixel.sound.FlxSound;

import funkin.states.MusicBeatState;
import funkin.states.TitleState;
import funkin.Paths;
import funkin.CoolUtil;
import funkin.scripts.Util.ModchartText;
import funkin.scripts.Util.DebugText;
import funkin.states.FreeplayState;

#if tgt
import funkin.tgt.MainMenuState;
import funkin.tgt.FreeplayState;
import funkin.tgt.StoryMenuState;
import funkin.tgt.ChapterMenuState;
import funkin.tgt.gallery.ComicsMenuState;
import funkin.tgt.gallery.GalleryMenuState;
import funkin.tgt.gallery.JukeboxState;
import funkin.tgt.gallery.TitleGalleryState;
import funkin.tgt.MenuButton;
import funkin.tgt.SinnerState;
import funkin.tgt.TGTMenuShit;
import funkin.tgt.TGTSquareButton;
import funkin.tgt.TGTTextButton;
import funkin.tgt.SquareTransitionSubstate;
#else
import funkin.states.SongSelectState as FreeplayState;
import funkin.states.SongSelectState as StoryMenuState;
#end

#end