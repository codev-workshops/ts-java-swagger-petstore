package io.swagger.petstore.bdd;

import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;
import org.junit.runner.RunWith;

@RunWith(Cucumber.class)
@CucumberOptions(
        features = "src/test/resources/features",
        glue = "io.swagger.petstore.bdd",
        plugin = {"pretty", "summary", "html:target/cucumber-reports/cucumber.html"}
)
public class RunCucumberTest {
}
