import handy_httpd;
import std.algorithm.searching;
import std.array;
import std.base64;
import std.format;
import std.getopt;
import std.path;
import std.stdio;
import provision;

static shared ADI* adi;
static __gshared ulong rinfo;

void main(string[] args) {
    auto serverConfig = ServerConfig.defaultValues;
    serverConfig.hostname = "0.0.0.0";
    serverConfig.port = 6969;

    auto helpInformation = getopt(
		    args,
		    "n|host", "The hostname to bind to", &serverConfig.hostname,
		    "p|port", "The port to bind to", &serverConfig.port,
    );
    if (helpInformation.helpWanted) {
        defaultGetoptPrinter("Server serving new ADI data fresh out of the oven.",
	    helpInformation.options);
	return;
    }

    adi = new shared ADI(expandTilde("~/.adi"), "");
    auto s = new HttpServer(simpleHandler((ref req, ref res) {
        if (req.url == "/reprovision") {
            writeln("[<<] GET /reprovision");
            adi.provisionDevice(rinfo);
            writeln("[>>] 200 OK");
            res.setStatus(200);
        } else {
            try {
                import std.datetime.systime;
                import std.datetime.timezone;
                import core.time;
                auto time = Clock.currTime();

                writefln("[<<] GET /");

                ubyte[] mid;
                ubyte[] otp;
                try {
                    adi.getOneTimePassword(mid, otp);
                } catch (Throwable) {
                    writeln("Reprovision needed.");
                    adi.provisionDevice(rinfo);
                    adi.getOneTimePassword(mid, otp);
                }

                import std.conv;
                import std.json;

                JSONValue response = [
                "X-Apple-I-Client-Time": time.toISOExtString.split('.')[0] ~ "Z",
                "X-Apple-I-MD":  Base64.encode(otp),
                "X-Apple-I-MD-M": Base64.encode(mid),
                "X-Apple-I-MD-RINFO": to!string(rinfo),
                "X-Apple-I-MD-LU": adi.localUserUUID,
                "X-Apple-I-SRL-NO": adi.serialNo,
                "X-MMe-Client-Info": adi.clientInfo,
                "X-Apple-I-TimeZone": time.timezone.dstName,
                "X-Apple-Locale": "en_US",
                "X-Mme-Device-Id": adi.deviceId,
                ];

                writefln!"[>>] 200 OK %s"(response);

                res.setStatus(200);
                res.addHeader("Content-Type", "application/json");
                res.writeBody(response.toString(JSONOptions.doNotEscapeSlashes));
            } catch(Throwable t) {
                res.setStatus(500);
                res.writeBody(t.toString());
            }
        }
    }), serverConfig);
    s.start();

    /+



    with (vib) {
        Get("/reprovision", (req, res) => "Hello World!");

        Get("", (req, res) {
        });
    }

    // listenHTTP is called automatically
    runApplication();

    scope (exit)
    vib.Stop();
    // +/
}
