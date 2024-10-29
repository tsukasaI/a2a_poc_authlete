import { createSignal, type Component } from "solid-js";
import { Route, Router, useSearchParams } from "@solidjs/router";
import axios from "axios";
import styles from "./App.module.css";

type CodeQuery = { code: string };

type TokenResponse = {
	access_token: string;
	refresh_token: string;
};

// For mobile
const clientId = "";
const responseType = "code";
const redirectUri = "http%3A%2F%2Flocalhost%3A3000%2Fcallback";
const scope = "openid";
const state = "aaaaa";
const codeChallenge = "";
const codeChallengeMethod = "S256";
const deepLink = `a2aauthlete://mobile?client_id=${clientId}&response_type=${responseType}&redirect_uri=${redirectUri}&scope=${scope}&state=${state}&code_challenge=${codeChallenge}&code_challenge_method=${codeChallengeMethod}`;

// For auth server
const clientSecret =
	"";
const codeVerifier = "";
const grantType = "authorization_code";


const Home: Component = () => {
	const openMobileApp = (): void => {
		document.location = deepLink;
	};
	return (
		<div class={styles.App}>
			<header class={styles.header}>
				<p>Client App Demo</p>
			</header>
			<div>
				<p>Start A2A Auth</p>
				<button type="button" onClick={openMobileApp}>
					Open Mobile App
				</button>
			</div>
		</div>
	);
};

const Callback: Component = () => {
	const [searchParams, _] = useSearchParams<CodeQuery>();
	const [accessToken, setAccessToken] = createSignal("");
	const [refreshToken, setRefreshToken] = createSignal("");

	const exchangeToken = (accessToken: string) => {
		axios
			.post<TokenResponse>("http://localhost:8888/token", {
				code: accessToken,
				state: state,
				client_id: clientId,
				client_secret: clientSecret,
				grant_type: grantType,
				redirect_uri: redirectUri,
				code_verifier: codeVerifier,
			})
			.then((res) => {
				setAccessToken(res.data.access_token);
				setRefreshToken(res.data.refresh_token);
			});
	};
	return (
		<div class={styles.App}>
			<header class={styles.header}>
				<p>Client App Demo</p>
			</header>
			{typeof searchParams.code !== "undefined" && (
				<button
					type="button"
					onClick={() => {
						exchangeToken(searchParams.code);
					}}
				>
					Exchange
				</button>
			)}

			<div>
				{accessToken() !== "" && <p>access_token: {accessToken()}</p>}
				{refreshToken() !== "" && <p>refresh_token: {refreshToken()}</p>}
			</div>
		</div>
	);
};

const App: Component = () => {
	return (
		<Router>
			<Route path="/" component={Home} />
			<Route path="/callback" component={Callback} />
		</Router>
	);
};

export default App;
