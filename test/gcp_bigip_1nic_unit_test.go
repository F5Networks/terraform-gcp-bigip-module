package test

import (
	"crypto/tls"
	"fmt"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformGCP1NicExample(t *testing.T) {

	t.Parallel()

	terraformOptions := &terraform.Options{

		TerraformDir: "../examples/bigip_gcp_1nic_deploy",

		Vars: map[string]interface{}{
			"region": "us-central1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	mgmtPublicIP := strings.Trim(terraform.Output(t, terraformOptions, "mgmtPublicIP"), "[]")
	bigipPassword := strings.Trim(terraform.Output(t, terraformOptions, "bigip_password"), "[]")
	bigipUsername := strings.Trim(terraform.Output(t, terraformOptions, "bigip_username"), "[]")
	mgmtPort := strings.Trim(terraform.Output(t, terraformOptions, "mgmtPort"), "[]")

	assert.NotEqual(t, "", mgmtPublicIP)
	assert.NotEqual(t, "", bigipPassword)
	assert.Equal(t, "bigipuser", bigipUsername)
	assert.Equal(t, "8443", mgmtPort)

	as3Url := fmt.Sprintf("https://%s:%s@%s:%s/mgmt/shared/appsvcs/info", bigipUsername, bigipPassword, mgmtPublicIP, mgmtPort)
	doUrl := fmt.Sprintf("https://%s:%s@%s:%s/mgmt/shared/declarative-onboarding/info", bigipUsername, bigipPassword, mgmtPublicIP, mgmtPort)
	// as3Url := fmt.Sprintf("https://%s:%s@%s:%s/mgmt/shared/appsvcs/info", bigipUsername, bigipPassword, mgmtPublicIP, mgmtPort)

	// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
	tlsConfig := tls.Config{
		InsecureSkipVerify: true,
	}

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		as3Url,
		&tlsConfig,
		10,
		10*time.Second,
		verifyAs3Resp,
	)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		doUrl,
		&tlsConfig,
		10,
		10*time.Second,
		verifyDoResp,
	)
}

func verifyAs3Resp(statusCode int, body string) bool {
	var respStr = `{"version":"3.34.0","release":"4","schemaCurrent":"3.34.0","schemaMinimum":"3.0.0"}`
	return statusCode == 200 && strings.Contains(body, respStr)
}

func verifyDoResp(statusCode int, body string) bool {
	var respStr = `"version":"1.27.0"`
	return statusCode == 200 && strings.Contains(body, respStr)
}
