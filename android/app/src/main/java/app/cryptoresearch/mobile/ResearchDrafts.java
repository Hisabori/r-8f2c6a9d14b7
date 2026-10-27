package app.cryptoresearch.mobile;
import android.content.Context;import android.text.*;import android.widget.EditText;
/** Local form drafts, separate from an executing account and all credentials. */
public final class ResearchDrafts {
 public static String bounded(String value){return value.substring(0,Math.min(32,value.length()));}
 public static String read(Context c,String scope,String key,String fallback){return bounded(c.getSharedPreferences("research-drafts",0).getString(scope+"."+key,fallback));}
 public static void bind(Context c,String scope,String key,EditText field,java.util.function.Consumer<String> changed){field.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(32)});field.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void afterTextChanged(Editable e){}public void onTextChanged(CharSequence value,int start,int before,int count){String text=bounded(value.toString());c.getSharedPreferences("research-drafts",0).edit().putString(scope+"."+key,text).apply();changed.accept(text);}});}
 private ResearchDrafts(){}
}
