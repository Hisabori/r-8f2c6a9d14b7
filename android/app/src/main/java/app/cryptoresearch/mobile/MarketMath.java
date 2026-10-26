package app.cryptoresearch.mobile;
import java.util.*;
/** Pure, deterministic quote math. No network, credentials, orders or implicit FX. */
public final class MarketMath {
 public static boolean valid(double price,long event,long received,long now,long maxEventAge){return Double.isFinite(price)&&price>0&&event>0&&received>0&&now-received<=15000&&now-received>=-5000&&now-event<=maxEventAge&&now-event>=-5000;}
 public static Double premium(double domestic,long de,long dr,double foreign,long fe,long fr,double fx,long now){if(!valid(domestic,de,dr,now,30000)||!valid(foreign,fe,fr,now,15000)||Math.abs(de-fe)>10000||!Double.isFinite(fx)||fx<=0)return null;return (domestic/(foreign*fx)-1)*100;}
 public static final class Alert {
  boolean primed=false,armed=true; long last=Long.MIN_VALUE/2;
  public boolean evaluate(Double value,double threshold,long now){if(value==null||!Double.isFinite(value)||threshold<=0)return false;double v=Math.abs(value);if(!primed){primed=true;armed=v<threshold;return false;}if(v<threshold-Math.min(.1,threshold*.2))armed=true;if(armed&&v>=threshold&&now-last>=60000){last=now;armed=false;return true;}return false;}
 }
 public static final class Quote {public double krw=Double.NaN,usd=Double.NaN,change=Double.NaN;public long ke,kr,ue,ur;}
 public static final class Point {public final long time;public final Double price,premium,gap;public Point(long t,Double p,Double v,Double g){time=t;price=p;premium=v;gap=g;}}
}
