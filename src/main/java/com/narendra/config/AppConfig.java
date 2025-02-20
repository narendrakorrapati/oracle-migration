package com.narendra.config;

import com.narendra.controller.FlywayStartupCommandLineRunner;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    @Bean
    public CommandLineRunner getCommandLineRunner() {
        return new FlywayStartupCommandLineRunner();
    }
}
