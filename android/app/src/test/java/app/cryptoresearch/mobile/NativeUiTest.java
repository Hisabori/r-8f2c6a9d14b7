package app.cryptoresearch.mobile;
import android.content.Intent;import android.os.Looper;import android.widget.*;import android.view.*;import org.junit.*;import org.junit.runner.RunWith;import org.robolectric.*;import org.robolectric.annotation.*;import static org.junit.Assert.*;import static org.robolectric.Shadows.shadowOf;
@RunWith(RobolectricTestRunner.class) @Config(sdk=28) @LooperMode(LooperMode.Mode.PAUSED)
public class NativeUiTest {
 org.robolectric.android.controller.ActivityController<MainActivity> controller;MainActivity app;
 @Before public void start(){controller=Robolectric.buildActivity(MainActivity.class);app=controller.create().start().resume().get();}
 @After public void stop(){controller.pause().stop().destroy();}
 @Test public void startsOffline(){assertFalse(app.requested);assertNotNull(app.root);assertEquals(4,app.nav.getChildCount());assertTrue(app.price.getText().toString().contains("—"));}
 @Test public void navigation(){for(int i=0;i<4;i++){app.nav.getChildAt(i).performClick();assertEquals(i,app.tab);assertTrue(app.body.getChildCount()>0);}}
 @Test public void favoritesPersist(){app.favorites.add("SOL");app.selected="SOL";app.save();assertTrue(app.prefs.getStringSet("favorites",java.util.Collections.emptySet()).contains("SOL"));assertEquals("SOL",app.prefs.getString("coin",""));}
 @Test public void publicFrames(){app.requested=true;long n=System.currentTimeMillis();app.receive("{\"code\":\"KRW-BTC\",\"trade_price\":142800,\"trade_timestamp\":"+n+",\"signed_change_rate\":0.01}",true,app.generation);app.receive("{\"data\":{\"s\":\"BTCUSDT\",\"c\":\"100\",\"E\":"+n+"}}",false,app.generation);shadowOf(Looper.getMainLooper()).idle();assertEquals(142800,app.quotes.get("BTC").krw,0.001);assertEquals(2,app.premium("BTC",n,1400),1e-8);app.requested=false;}
 @Test public void rejectsOldGeneration(){app.requested=true;app.receive("{\"code\":\"KRW-BTC\",\"trade_price\":1,\"trade_timestamp\":1800000000000}",true,app.generation-1);shadowOf(Looper.getMainLooper()).idle();assertTrue(Double.isNaN(app.quotes.get("BTC").krw));app.requested=false;}
 @Test public void backgroundStopsSockets(){app.requested=false;controller.pause().stop();assertFalse(app.active);assertNull(app.up);assertNull(app.bin);controller.start().resume();}
 @Test public void reportAndSettings(){app.tab=2;app.build();assertTrue(app.research.contains("Python"));app.tab=3;app.build();assertTrue(app.body.getChildCount()>=2);}
}
