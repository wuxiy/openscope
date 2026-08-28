package dev.openscope.sample;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * OpenScope V0.1 sample application.
 *
 * The ONLY instrumentation is the OpenTelemetry Java Agent attached at JVM start
 * (`-javaagent:...`). This application intentionally does NOT depend on any OTel
 * or OpenScope SDK/starter — telemetry is exported by the agent over OTLP/HTTP.
 */
@SpringBootApplication
public class OpenScopeSampleApplication {

    public static void main(String[] args) {
        SpringApplication.run(OpenScopeSampleApplication.class, args);
    }
}