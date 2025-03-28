package funkin.objects.hud;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxStringUtil;
import flixel.ui.FlxBar;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.states.PlayState;

/**
	Joke. Taken from V Slice Engine kinda?
**/
class DefHUD extends BaseHUD
{
	var healthBar:FNFHealthBar;
	var healthBarBG:FlxSprite;

	var iconP1:HealthIcon;
	var iconP2:HealthIcon;

	var scoreTxt:FlxText;

	var scoreString = Paths.getString("score");

	private var cpuControlled(get, never):Bool;
	inline function get_cpuControlled() return PlayState.instance.cpuControlled;

	override function set_displayedHealth(value:Float)
	{
		healthBar.value = value;
		displayedHealth = value;
		return value;
	}

	override function getHealthbar():FNFHealthBar 
		return healthBar;

	public function new(iP1:String, iP2:String, songName:String, stats:Stats)
	{
		super(iP1, iP2, songName, stats);

		//// Health bar
		healthBar = new FNFHealthBar(iP1, iP2);
		healthBar.VSliceUI = true;
		healthBarBG = healthBar.healthBarBG;
		iconP1 = healthBar.iconP1;
		iconP2 = healthBar.iconP2;
		
		scoreTxt = new FlxText(healthBarBG.x + healthBarBG.width - 190, healthBarBG.y + 30, 0, '', 20);
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		add(scoreTxt);

		add(healthBarBG);
		add(healthBar);
		add(iconP1);
		add(iconP2);

		timeBarBG = new FlxSprite(0, (ClientPrefs.downScroll) ? (FlxG.height * 0.9 + 45) : 10, healthBarBG.graphic);
		timeBarBG.color = 0xFF000000;
		timeBarBG.alpha = 0;
		timeBarBG.visible = false;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), null, null, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(FlxColor.GRAY, FlxColor.LIME);
		timeBar.numDivisions = timeBar.barWidth;
		timeBar.alpha = 0;
		timeBar.visible = false;
		add(timeBar);

		timeTxt = new FlxText(timeBarBG.x + (timeBarBG.width / 2) - (songName.length * 5), timeBarBG.y, 0, songName, 16);
		timeTxt.y = (ClientPrefs.downScroll) ? (timeBarBG.y - 3) : timeBarBG.y;
		timeTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.visible = false;
		add(timeTxt);

		// fuck it
		changedOptions([]);
	}

	override function changedOptions(changed){
		super.changedOptions(changed);

		healthBar.y = (ClientPrefs.downScroll) ? 50 : (FlxG.height * 0.9);
		healthBar.iconP1.y = healthBar.y - 75;
		healthBar.iconP2.y = healthBar.y - 75;
		healthBar.update(0);

		scoreTxt.y = (healthBarBG.y + 50);
	}

	override function reloadHealthBarColors(dadColor:FlxColor, bfColor:FlxColor)
	{
		if (healthBar != null)
		{
			healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
			healthBar.updateBar();
		}
	}

	override function beatHit(beat:Int)
	{
		healthBar.bopBeatV();
	}

	override function update(elapsed:Float)
	{
		for (i in [timeBarBG, timeBar, timeTxt]) {
			if (i != null) {
				i.alpha = 0; i.visible = false;
			}
		}

		if (FlxG.keys.justPressed.NINE)
			iconP1.swapOldIcon();

		if (isUpdating){
			scoreTxt.text = 'Score:' + Std.string(score);
			if (cpuControlled == true) {
				scoreTxt.text = 'Bot Play Enabled';
			}
		}
		super.update(elapsed);
	}
}