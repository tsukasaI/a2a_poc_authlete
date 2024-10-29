package main

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/authlete/authlete-go/api"
	"github.com/authlete/authlete-go/conf"
	"github.com/authlete/authlete-go/dto"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

const (
	port = 8888
)

var (
	base_url           = ""
	service_api_key    = ""
	service_api_secret = ""
	authApiClient      api.AuthleteApi
)

type (
	AuthRequest struct {
		ClientID            string `json:"client_id"`
		ResponseType        string `json:"response_type"`
		RedirectURI         string `json:"redirect_uri"`
		Scope               string `json:"scope"`
		State               string `json:"state"`
		CodeChallenge       string `json:"code_challenge"`
		CodeChallengeMethod string `json:"code_challenge_method"`
	}
	AuthRespone struct {
		Ticket string `json:"ticket"`
	}
	ConsentRequest struct {
		Ticket   string `json:"ticket"`
		MemberID int    `json:"member_id"`
	}
	ConsentResponse struct {
		RedirectTo string `json:"redirect_to"`
	}
	TokenExchangeRequest struct {
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
		GrantType    string `json:"grant_type"`
		Code         string `json:"code"`
		RedirectUri  string `json:"redirect_uri"`
		CodeVerifier string `json:"code_verifier"`
		State        string `json:"state"`
	}
	TokenExchangeResponse struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
)

func main() {
	setConfigurations()

	runAuthApiServer()
}

func runAuthApiServer() {
	e := echo.New()
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"http://localhost:3000"},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept},
	}))

	e.POST("/auth", auth)
	e.POST("/consent", consent)
	e.POST("/token", token)

	e.Logger.Fatal(e.Start(fmt.Sprintf(":%d", port)))
}

// Endpoints
// Issue ticket
func auth(c echo.Context) error {
	req := new(AuthRequest)
	err := c.Bind(req)
	if err != nil {
		return err
	}

	authRes, apiErr := callAuthorizationApi(req)
	if apiErr != nil {
		return apiErr
	}

	c.JSON(http.StatusOK, AuthRespone{Ticket: authRes.Ticket})
	return nil
}

// Consent
func consent(c echo.Context) error {
	req := new(ConsentRequest)
	err := c.Bind(req)
	if err != nil {
		return err
	}

	authIssueRes, apiErr := callAuthorizationIssueApi(req.Ticket, strconv.Itoa(req.MemberID))
	if apiErr != nil {
		return err
	}

	c.JSON(http.StatusOK, ConsentResponse{
		RedirectTo: authIssueRes.ResponseContent,
	})
	return nil
}

// Token exchange
func token(c echo.Context) error {
	req := new(TokenExchangeRequest)
	err := c.Bind(req)
	if err != nil {
		return err
	}

	apiRes, apiErr := callTokenApi(req)
	if apiErr != nil {
		return err
	}

	callIntrospection(apiRes.AccessToken)

	c.JSON(http.StatusOK, TokenExchangeResponse{
		AccessToken:  apiRes.AccessToken,
		RefreshToken: apiRes.RefreshToken,
	})
	return nil
}

func setConfigurations() {
	cnf := new(conf.AuthleteSimpleConfiguration)
	cnf.SetBaseUrl(base_url)
	cnf.SetServiceApiKey(service_api_key)
	cnf.SetServiceApiSecret(service_api_secret)

	authApiClient = api.New(cnf)
}

func callAuthorizationApi(clientReq *AuthRequest) (*dto.AuthorizationResponse, *api.AuthleteError) {
	req := dto.AuthorizationRequest{
		Parameters: fmt.Sprintf(
			`response_type=%s&client_id=%s&redirect_uri=%s&scope=%s&state=%s&code_challenge=%s&code_challenge_method=%s`,
			clientReq.ResponseType,
			clientReq.ClientID,
			clientReq.RedirectURI,
			clientReq.Scope,
			clientReq.State,
			clientReq.CodeChallenge,
			clientReq.CodeChallengeMethod,
		),
	}

	return authApiClient.Authorization(&req)
}

func callAuthorizationIssueApi(ticket, userID string) (
	*dto.AuthorizationIssueResponse, *api.AuthleteError,
) {
	req := dto.AuthorizationIssueRequest{
		Ticket:  ticket,
		Subject: userID,
	}

	return authApiClient.AuthorizationIssue(&req)
}

func callTokenApi(clientReq *TokenExchangeRequest) (*dto.TokenResponse, *api.AuthleteError) {
	req := dto.TokenRequest{
		Parameters: fmt.Sprintf("grant_type=%s&state=%s&code=%s&redirect_uri=%s&code_verifier=%s",
			clientReq.GrantType, clientReq.State, clientReq.Code, clientReq.RedirectUri, clientReq.CodeVerifier,
		),
		ClientId:     clientReq.ClientID,
		ClientSecret: clientReq.ClientSecret,
	}

	return authApiClient.Token(&req)
}

func callIntrospection(accessToken string) {
	introReq := &dto.IntrospectionRequest{
		Token:  accessToken,
		Scopes: []string{"openid"},
	}

	res, err := authApiClient.Introspection(introReq)
	fmt.Printf("Introspection res:\n%#v\n\n", res)
	fmt.Printf("Introspection err:\n%#v\n\n", err)
}
