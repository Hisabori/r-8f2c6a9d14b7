package app.cryptoresearch.mobile;
import android.app.Activity;import android.content.Intent;import android.net.Uri;import org.json.JSONObject;import java.io.*;import java.nio.charset.StandardCharsets;
public final class ServerReportExport {
 public static byte[] validated(byte[] raw)throws Exception {if(raw.length==0||raw.length>8*1024*1024)throw new IOException("8MB 이하 서버 리포트가 필요합니다");JSONObject j=new JSONObject(new String(raw,StandardCharsets.UTF_8));if(!"SERVER_PAPER_EMA_SPOT_V2".equals(j.optString("mode"))||j.optInt("report_schema_version")!=2)throw new IOException("서버 모의 리포트 형식 확인 필요");return raw.clone();}
 public static void share(Activity a,byte[] raw)throws Exception {byte[] data=validated(raw);String name="research-"+System.currentTimeMillis()+".json";try(FileOutputStream f=new FileOutputStream(new File(a.getCacheDir(),name))){f.write(data);}Intent intent=new Intent(Intent.ACTION_SEND).setType("application/json").putExtra(Intent.EXTRA_STREAM,Uri.parse("content://app.cryptoresearch.mobile.exports/"+name)).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);a.startActivity(Intent.createChooser(intent,"서버 모의 리포트 저장/공유"));}
 private ServerReportExport(){}
}
