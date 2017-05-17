import std.stdio, std.regex, std.json, std.file, std.datetime, std.conv, std.process, std.net.curl, std.string;
import qobuz.api;

int main(string[] args)
{
  string VERSION = "1.2";

  if (args.length != 2) {
    writefln("Usage: %s <album id or url>", args[0]);
    return -1;
  }

  auto path = thisExePath();
  path = path.replaceFirst(regex("qobuz-get(\\.exe)?$"), "magic.json"); // HACK
  string json;
  try {
    json = readText(path);
  } catch (Exception e) {
    writeln("Could not open magic.json!");
  }
  auto magic = parseJSON(json);
  
  // strip url part if we have it
  string id;
  auto urlPart = regex("^https?://play.qobuz.com/album/");
  if (args[1].matchFirst(urlPart)) {
    id = args[1].replaceFirst(urlPart, "");
  } else {
    id = args[1];
  }

  writeln("Looking up album...");
  auto album = getAlbum(magic, id);

  string title, artist, genre, year;
  JSONValue[] tracks;

  try {
    title = album["title"].str;
    artist = album["artist"]["name"].str;
    genre = album["genre"]["name"].str;
    auto releaseTime = SysTime.fromUnixTime(album["released_at"].integer, UTC());
    year = releaseTime.year.text;

    writefln("[ %s - %s (%s, %s) ]", artist, title, genre, year);

    tracks = album["tracks"]["items"].array();
  } catch (Exception e) {
    writeln("Could not parse album data!");
    return -4;
  }

  string dirName = artist~" - "~title~" ("~year~") [WEB FLAC]";
  try {
    mkdir(dirName);
  } catch (Exception e) {
    writeln("Could not create directory: `"~dirName~"`. Does it exist already?");
    return -9;
  }

  auto discs = tracks[tracks.length - 1]["media_number"].integer;

  foreach (track; tracks) {
    string url, num, discNum, trackName, trackArtist;
    try {
      num = track["track_number"].integer.text;
      discNum = track["media_number"].integer.text;
      trackName = track["title"].str;
      trackArtist = track["performer"]["name"].str;
      if (num.length < 2)
        num = "0"~num;
      writef(" [%s/%s] %s... ", discNum, num, trackName);
      stdout.flush;
      url = getDownloadUrl(magic, track["id"].integer.text);
    } catch (Exception e) {
      writeln("Failed to parse track data!");
      return -7;
    }

    string discDir;
    if (discs > 1)
      discDir = dirName~"/Disc "~discNum;
    else
      discDir = dirName;

    if (!discDir.exists || !discDir.isDir) {
      try {
        mkdir(discDir);
      } catch (Exception e) {
        writeln("Failed to create directory `"~discDir~"`.");
        return -11;
      }
    }

    try {
      auto pipes = pipeProcess([magic["ffmpeg"].str, "-i", "-", "-metadata", "title="~trackName, "-metadata", "artist="~trackArtist,
          "-metadata", "album="~title, "-metadata", "year="~year, "-metadata", "track="~num, "-metadata", "genre="~genre,
          "-metadata", "albumartist="~artist, "-metadata", "discnumber="~discNum, "-metadata", "tracktotal="~tracks.length.text,
          "-metadata", "disctotal="~discs.text, discDir~"/"~num~" - "~trackName~".flac"],
          Redirect.stdin | Redirect.stderr | Redirect.stdout);
      foreach (chunk; byChunkAsync(url, 1024)) {
        pipes.stdin.rawWrite(chunk);
        pipes.stdin.flush;
      }
      pipes.stdin.close;
      wait(pipes.pid);
    } catch (Exception e) {
      writeln("Failed to download track! Check that ffmpeg is properly configured.");
      return -8;
    }
    writeln("Done!");
  }

  string firstDisc;
  if (discs > 1)
    firstDisc = dirName~"/Disc 1";
  else
    firstDisc = dirName;

  // Get album art
  write("Getting album art... ");
  stdout.flush;
  download(id.getArtUrl, firstDisc~"/cover.jpg");
  for (int i = 2; i <= discs; i++) {
    copy(firstDisc~"/cover.jpg", dirName~"/Disc "~i.text~"/cover.jpg");
  }
  writeln("Done!");

  string choice;
  while (choice != "n" && choice != "y") {
    write("Generate spectrals? [y/n] ");
    stdout.flush;
    choice = readln().chomp;
  }
  if (choice == "y") {
    try {
      auto full = execute([magic["sox"].str, firstDisc~"/01 - "~tracks[0]["title"].str~".flac", "-n", "remix", "1", "spectrogram",
          "-x", "3000", "-y", "513", "-z", "120", "-w", "Kaiser", "-o", "SpecFull.png"]);
      auto zoom = execute([magic["sox"].str, firstDisc~"/01 - "~tracks[0]["title"].str~".flac", "-n", "remix", "1", "spectrogram",
          "-X", "500", "-y", "1025", "-z", "120", "-w", "Kaiser", "-S", "0:30", "-d", "0:04", "-o", "SpecZoom.png"]);
      if (full.status != 0 || zoom.status != 0)
        throw new Exception("sox failed");
      writeln("SpecFull.png and SpecZoom.png written.");
    } catch (Exception e) {
      writeln("Generating spectrals failed! Is sox configured properly?");
    }
  }

  choice = null;
  while (choice != "n" && choice != "y") {
    write("Create .torrent file? [y/n] ");
    stdout.flush;
    choice = readln().chomp;
  }
  if (choice == "y") {
    write("Announce URL: ");
    stdout.flush;
    string announce = readln().chomp;

    try {
    auto t = execute([magic["mktorrent"].str, "-l", "20", "-a", announce, dirName]);
    if (t.status != 0)
      throw new Exception("mktorrent failed");
    writeln("'"~dirName~".torrent' created.");
    } catch (Exception e) {
      writeln("Creating .torrent file failed! Is mktorrent configured properly?");
    }
  }

  writeln("All done, exiting.");

  return 0;
}
