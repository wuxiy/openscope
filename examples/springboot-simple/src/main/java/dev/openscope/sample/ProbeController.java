package dev.openscope.sample;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/** Three probe endpoints used by the V0.1 acceptance script. */
@RestController
public class ProbeController {

    private static final Logger log = LoggerFactory.getLogger(ProbeController.class);

    @GetMapping("/ok")
    public String ok(@RequestHeader(value = "Authorization", required = false) String auth,
                     @RequestHeader(value = "Cookie", required = false) String cookie) {
        log.info("probe /ok called, authPresent={}, cookiePresent={}", auth != null, cookie != null);
        return "ok";
    }

    @GetMapping("/fail")
    public String fail() {
        RuntimeException e = new IllegalStateException("synthetic failure for V0.1 acceptance");
        log.error("probe /fail raised", e);
        throw e;
    }

    /** Returns the caller-supplied canary value so a leak in request/response body capture would be detectable. */
    @GetMapping("/sensitive")
    public String sensitive(@RequestHeader(value = "X-CANARY", required = false) String canary) {
        log.info("probe /sensitive canary={}", canary);
        return canary == null ? "no-canary" : canary;
    }
}