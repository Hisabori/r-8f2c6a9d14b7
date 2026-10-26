package app.cryptoresearch.mobile;
import org.junit.Test;import static org.junit.Assert.*;
public class MarketMathTest {
 final long n=1800000000000L;
 @Test public void premium(){assertEquals(2,MarketMath.premium(142800,n,n,100,n,n,1400,n),1e-8);assertEquals(-2,MarketMath.premium(137200,n,n,100,n,n,1400,n),1e-8);}
 @Test public void missingFx(){assertNull(MarketMath.premium(142800,n,n,100,n,n,Double.NaN,n));assertNull(MarketMath.premium(142800,n,n,100,n,n,0,n));}
 @Test public void invalidPrices(){assertNull(MarketMath.premium(0,n,n,100,n,n,1400,n));assertNull(MarketMath.premium(Double.NaN,n,n,100,n,n,1400,n));assertNull(MarketMath.premium(1,n,n,Double.POSITIVE_INFINITY,n,n,1400,n));}
 @Test public void staleReceive(){assertNull(MarketMath.premium(142800,n,n-16000,100,n,n,1400,n));assertNull(MarketMath.premium(142800,n,n,100,n,n-16000,1400,n));}
 @Test public void staleTrade(){assertNull(MarketMath.premium(142800,n-31000,n,100,n,n,1400,n));assertNull(MarketMath.premium(142800,n,n,100,n-16000,n,1400,n));}
 @Test public void futureClock(){assertNull(MarketMath.premium(142800,n+6000,n,100,n,n,1400,n));assertFalse(MarketMath.valid(1,n,n+6000,n,30000));}
 @Test public void skew(){assertNull(MarketMath.premium(142800,n-11000,n,100,n,n,1400,n));assertNotNull(MarketMath.premium(142800,n-10000,n,100,n,n,1400,n));}
 @Test public void startupPrime(){MarketMath.Alert a=new MarketMath.Alert();assertFalse(a.evaluate(3.,2,n));assertFalse(a.evaluate(null,2,n));assertFalse(a.evaluate(3.,2,n+60000));}
 @Test public void rearmAndCooldown(){MarketMath.Alert a=new MarketMath.Alert();assertFalse(a.evaluate(1.,2,n));assertTrue(a.evaluate(2.,2,n));assertFalse(a.evaluate(1.,2,n+1000));assertFalse(a.evaluate(2.,2,n+10000));assertTrue(a.evaluate(2.,2,n+60000));}
 @Test public void hysteresis(){MarketMath.Alert a=new MarketMath.Alert();a.evaluate(1.,2,n);assertTrue(a.evaluate(2.,2,n));a.evaluate(1.95,2,n+60000);assertFalse(a.evaluate(2.,2,n+60000));a.evaluate(1.89,2,n+60000);assertTrue(a.evaluate(-2.,2,n+60000));}
}
