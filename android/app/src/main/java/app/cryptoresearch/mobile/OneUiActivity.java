package app.cryptoresearch.mobile;
import android.app.Activity;import android.content.*;import android.content.res.Configuration;import android.os.Bundle;import android.view.View;
public class OneUiActivity extends Activity {
 boolean appliedDark;
 protected void attachBaseContext(Context base){String mode=base.getSharedPreferences(OneUi.PREF,MODE_PRIVATE).getString(OneUi.MODE,"system");if(!mode.equals("system")){Configuration c=new Configuration(base.getResources().getConfiguration());c.uiMode=(c.uiMode&~Configuration.UI_MODE_NIGHT_MASK)|(mode.equals("dark")?Configuration.UI_MODE_NIGHT_YES:Configuration.UI_MODE_NIGHT_NO);base=base.createConfigurationContext(c);}super.attachBaseContext(base);}
 public void onCreate(Bundle state){setTheme(OneUi.dark(this)?R.style.AppThemeDark:R.style.AppThemeLight);super.onCreate(state);appliedDark=OneUi.dark(this);getWindow().setStatusBarColor(OneUi.bg(this));getWindow().setNavigationBarColor(OneUi.surface(this));getWindow().getDecorView().setSystemUiVisibility(OneUi.dark(this)?0:View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);}
 public void onConfigurationChanged(Configuration c){super.onConfigurationChanged(c);if(appliedDark!=OneUi.dark(this))recreate();}
}
