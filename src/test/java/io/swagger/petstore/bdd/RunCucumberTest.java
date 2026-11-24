package io.swagger.petstore.bdd;

import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;
import org.junit.runner.RunWith;

/**
 * Runs features/*.feature against an embedded Petstore server (or -Dpetstore.baseUrl=...).
 * Scenarios tagged @known-gap document spec behavior the server does not implement yet and are
 * excluded by default; run them with -Dcucumber.filter.tags="@known-gap".
 */
@RunWith(Cucumber.class)
@CucumberOptions(
        features = "features",
        glue = "io.swagger.petstore.bdd",
        tags = "not @known-gap",
        plugin = {
                "summary",
                "html:target/cucumber-reports/cucumber.html",
                "json:target/cucumber-reports/cucumber.json",
                "junit:target/cucumber-reports/cucumber.xml"
        })
public class RunCucumberTest {
}
