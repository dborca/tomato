/*

	Tomato Firmware
	Copyright (C) 2006-2008 Jonathan Zarate

*/

#include "tomato.h"

#include <ctype.h>
#include <wlutils.h>


//	returns: ['bssid','ssid',channel,capabilities,rssi,noise,[rates,]],  or  [null,'error message']
void asp_wlscan(int argc, char **argv)
{
	// scan

	wl_scan_params_t sp;
	int ap;
	int radio;
	char *wif;
	int zero = 0;

	web_puts("\nwlscandata = [");

	wif = nvram_safe_get("wl_ifname");

	memset(&sp, 0xff, sizeof(sp));		// most default to -1
	memset(&sp.bssid, 0xff, sizeof(sp.bssid));		//!!TB
	sp.ssid.SSID_len = 0;
	sp.bss_type = DOT11_BSSTYPE_ANY;	// =2
	sp.channel_num = 0;
	sp.scan_type = DOT11_SCANTYPE_PASSIVE;	// =1	//!!TB

	if (wl_ioctl(wif, WLC_GET_AP, &ap, sizeof(ap)) < 0) {
		web_puts("[null,'Unable to get AP mode.']];\n");
		return;
	}
	if (ap > 0) {
		wl_ioctl(wif, WLC_SET_AP, &zero, sizeof(zero));
	}
	
	radio = get_radio();
	if (!radio) set_radio(1);
	
	if (wl_ioctl(wif, WLC_SCAN, &sp, WL_SCAN_PARAMS_FIXED_SIZE) < 0) {
		if (ap > 0) wl_ioctl(wif, WLC_SET_AP, &ap, sizeof(ap));
		if (!radio) set_radio(0);
		web_puts("[null,'Unable to start scan.']];\n");
		return;
	}

	sleep(2);


	// get results

	wl_scan_results_t *results;
	wl_bss_info_t *bssi;
	int r;

	results = malloc(WLC_IOCTL_MAXLEN);
	if (!results) {
		if (ap > 0) wl_ioctl(wif, WLC_SET_AP, &ap, sizeof(ap));
		if (!radio) set_radio(0);
		web_puts("[null,'Not enough memory.']];");
		return;
	}
	results->buflen = WLC_IOCTL_MAXLEN - (sizeof(*results) - sizeof(results->bss_info));
	results->version = WL_BSS_INFO_VERSION;

	//!!TB - keep trying to obtain scan results for up to 3 more secs 
	//Passive scan may require more time, although 1 extra sec is almost always enough.
	int t;
	for (t = 0; t < 30; t++) {
		r = wl_ioctl(wif, WLC_SCAN_RESULTS, results, WLC_IOCTL_MAXLEN);
		if (r >= 0)
			break;
		usleep(100000);
	}

	if (ap > 0) {
		wl_ioctl(wif, WLC_SET_AP, &ap, sizeof(ap));
#ifndef WL_BSS_INFO_VERSION
#error WL_BSS_INFO_VERSION
#endif

		eval("wl", "up"); //!!TB - without this the router may reboot
#if WL_BSS_INFO_VERSION >= 108
		//!!TB - it seems that the new WL driver needs another voodoo sequence
		eval("wl", "ssid", "");

		// no idea why this voodoo sequence works to wake up wl	-- zzz
		eval("wl", "ssid", nvram_safe_get("wl_ssid"));
		if (radio) set_radio(1);
#endif
	}
	//!!TB if (!radio)
	set_radio(radio);
	
	if (r < 0) {
		free(results);
		web_puts("[null,'Unable to obtain scan result.']];\n");
		return;
	}


	// format for javascript

	int i;
	int j;
	int k;
	char c;
	char ssid[64];
	char mac[32];
	char *ssidj;
	int channel;
	
	bssi = &results->bss_info[0];
	for (i = 0; i < results->count; ++i) {

#if WL_BSS_INFO_VERSION >= 108
		channel = CHSPEC_CHANNEL(bssi->chanspec);
#else
		channel = bssi->channel;
#endif

		// scrub ssid
		j = bssi->SSID_len;
		if (j < 0) j = 0;
		if (j > 32) j = 32;
		for (k = j - 1; k >= 0; --k) {
			c = bssi->SSID[k];
			if (!isprint(c)) c = '?';
			ssid[k] = c;
		}
		ssid[j] = 0;
		
		ssidj = js_string(ssid);
		web_printf("%s['%s','%s',%u,%u,%d,%d,[", (i > 0) ? "," : "",
			ether_etoa(bssi->BSSID.octet, mac), ssidj ? ssidj : "",
			channel,
			bssi->capability, bssi->RSSI, bssi->phy_noise);
		free(ssidj);
		
		for (j = 0; j < bssi->rateset.count; ++j) {
			web_printf("%s%u", j ? "," : "", bssi->rateset.rates[j]);
		}
		web_puts("]]");

		bssi = (wl_bss_info_t*)((uint8*)bssi + bssi->length);
	}

	web_puts("];\n");
	free(results);
}


void asp_wlradio(int argc, char **argv)
{
	web_printf("\nwlradio = %d;\n", get_radio());
}

void wo_wlradio(char *url)
{
	char *enable;
	
	parse_asp("saved.asp");
	if (nvram_match("wl_radio", "1")) {
		if ((enable = webcgi_get("enable")) != NULL) {
			web_close();
			sleep(2);
			eval("radio", atoi(enable) ? "on" : "off");
			return;
		}
	}
}

static int read_noise(void)
{
	int v;
	
	// WLC_GET_PHY_NOISE = 135
	if (wl_ioctl(nvram_safe_get("wl_ifname"), 135, &v, sizeof(v)) == 0) {
		char s[32];
		sprintf(s, "%d", v);
		nvram_set("t_noise", s);
		return v;
	}
	return -99;
}

void asp_wlcrssi(int argc, char **argv)
{
	scb_val_t rssi;

	memset(&rssi, 0, sizeof(rssi));
	if (wl_client()) {
		if (wl_ioctl(nvram_safe_get("wl_ifname"), WLC_GET_RSSI, &rssi, sizeof(rssi)) != 0)
			rssi.val = -100;
	}
	web_printf("\nwlcrssi = %d;\n", rssi.val);
}

void asp_wlnoise(int argc, char **argv)
{
	int v;
	
	if (wl_client()) {
		v = read_noise();
	}
	else {
		v = nvram_get_int("t_noise");
		if ((v > 0) || (v < -100)) v = -99;
	}
	web_printf("\nwlnoise = %d;\n", v);
}

void wo_wlmnoise(char *url)
{
	int ap;
	int i;
	char *wif;
	
	parse_asp("mnoise.asp");
	web_close();
	sleep(3);

	int radio = get_radio();	//!!TB

	wif = nvram_safe_get("wl_ifname");
	if (wl_ioctl(wif, WLC_GET_AP, &ap, sizeof(ap)) < 0) return;

	i = 0;
	wl_ioctl(wif, WLC_SET_AP, &i, sizeof(i));
	
	for (i = 10; i > 0; --i) {
		sleep(1);
		read_noise();
	}
	
	wl_ioctl(wif, WLC_SET_AP, &ap, sizeof(ap));

	//!!TB - again, the same voodoo sequence seems to be needed for new WL driver
	if (!radio) set_radio(1);
	eval("wl", "up");
#if WL_BSS_INFO_VERSION >= 108
	eval("wl", "ssid", "");
	eval("wl", "ssid", nvram_safe_get("wl_ssid"));
#endif
	set_radio(radio);
}

void asp_wlclient(int argc, char **argv)
{
	web_puts(wl_client() ? "1" : "0");
}

void asp_wlchannel(int argc, char **argv)
{
	channel_info_t ch;
	
	if (wl_ioctl(nvram_safe_get("wl_ifname"), WLC_GET_CHANNEL, &ch, sizeof(ch)) < 0) {
		web_puts(nvram_safe_get("wl_channel"));
	}
	else {
		web_printf("%d", (ch.scan_channel > 0) ? -ch.scan_channel : ch.hw_channel);
	}
}

void asp_wlchannels(int argc, char **argv)
{
	char s[40];
	int d[14];
	FILE *f;
	int n, i;
	const char *ghz[] = {
		"2.412", "2.417", "2.422", "2.427", "2.432", "2.437", "2.442",
		"2.447", "2.452", "2.457", "2.462", "2.467", "2.472", "2.484"};

	web_puts("\nwl_channels = [\n['0', 'Auto']");
	if ((f = popen("wl channels", "r")) != NULL) {
		if (fgets(s, sizeof(s), f)) {
			n = sscanf(s, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d",
				&d[0], &d[1], &d[2], &d[3],  &d[4],  &d[5],  &d[6],
				&d[7], &d[8], &d[9], &d[10], &d[11], &d[12], &d[13]);
			for (i = 0; i < n; ++i) {
				if (d[i] <= 14) {
					web_printf(",['%d', '%d - %s GHz']",
						d[i], d[i], ghz[d[i] - 1]);
				}
			}
		}
		fclose(f);
	}
	web_puts("];\n");
}

#if 0
void asp_wlcountries(int argc, char **argv)
{
	char *js, s[128], code[15], country[64];
	FILE *f;
	int i = 0;

	web_puts("\nwl_countries = [\n");
	if ((f = popen("wl country list", "r")) != NULL) {
		while (fgets(s, sizeof(s), f)) {
			if (sscanf(s, "%s %s", code, country) == 2) {
				// skip all bogus country names
				if (strlen(code) < 5 && strcmp(code, country) != 0) {
					js = js_string(strstr(s, country));
					web_printf("%c['%s', '%s']", i == 0 ? ' ' : ',', code, js);
					free(js);
					i++;
				}
			}
		}
		fclose(f);
	}
	web_puts("];\n");
}
#endif
