module qobuz.api;
import core.stdc.stdlib, std.digest.md, std.conv, std.uni, std.json, std.net.curl, std.stdio, std.datetime;
import std.algorithm : sort;

string createSignature(string obj, string method, string[string] params, string tstamp, string secret) {
  string str = obj;
  str ~= method;
  foreach (k; sort(params.keys)) {
    str ~= k ~ params[k];
  }
  str ~= tstamp;
  str ~= secret;

  auto md5 = new MD5Digest();
  return md5.digest(str).toHexString.toLower;
}

string apiRequest(JSONValue magic, string request) {
  auto curl = HTTP();
  curl.addRequestHeader("x-app-id", magic["app_id"].str);
  curl.addRequestHeader("x-user-auth-token", magic["user_auth_token"].str);
//  curl.proxy = "localhost:8080";

  string jsonResponse;
  try {
    jsonResponse = get("http://qobuz.com/api.json/0.2/"~request, curl).text();
  } catch (Exception e) {
    writeln("Request to qobuz failed!");
    exit(-2);
  }

  return jsonResponse;
}

JSONValue getAlbum(JSONValue magic, string id) {
  try {
    return apiRequest(magic, "album/get?offset=0&limit=500&album_id="~id).parseJSON;
  } catch (Exception e) {
    writeln("Invalid JSON data!");
    exit(-3);
  }

  assert(0);
}

string buildGETRequest(string[string] params) {
  string req;
  foreach (i, k; params.keys) {
    if (i == 0)
      req ~= "?";
    else
      req ~= "&";
    req ~= k~"="~params[k];
  }
  return req;
}

string getDownloadUrl(JSONValue magic, string id) {
  string[string] params;
  params["track_id"] = id;
  params["format_id"] = "6"; // TODO: support for multiple formats
  params["intent"] = "stream";

  auto tstamp = Clock.currTime.toUnixTime.text;
  auto sig = createSignature("track", "getFileUrl", params, tstamp, magic["app_secret"].str);

  JSONValue response;
  try {
    response = apiRequest(magic, "track/getFileUrl"~buildGETRequest(params)~"&request_ts="~tstamp~"&request_sig="~sig).parseJSON;
  } catch (Exception e) {
    writeln("Invalid JSON data!");
    exit(-5);
  }
  try {
    return response["url"].str;
  } catch (Exception e) {
    writeln("No download URI given!");
    exit(-6);
  }

  assert(0);
}

string getArtUrl(string id) {
  if (id.length != 13) {
    writeln("Album ID of invalid length given!");
    exit(-10);
  }

  string a = id[11..13];
  string b = id[9..11];
  return "http://static.qobuz.com/images/covers/"~a~"/"~b~"/"~id~"_max.jpg";
}

// ex: set tabstop=2 expandtab:
