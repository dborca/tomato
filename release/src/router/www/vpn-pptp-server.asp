<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.0//EN'>
<!--
	Tomato PPTPd GUI
	Copyright (C) 2012 Augusto Bott
	http://code.google.com/p/tomato-sdhc-vlan/

	Tomato GUI
	Copyright (C) 2006-2007 Jonathan Zarate
	http://www.polarcloud.com/tomato/
	For use with Tomato Firmware only.
	No part of this file may be used without permission.
-->
<html>
<head>
<meta http-equiv='content-type' content='text/html;charset=utf-8'>
<meta name='robots' content='noindex,nofollow'>
<title>[<% ident(); %>] VPN: Serwer PPTP</title>
<link rel='stylesheet' type='text/css' href='tomato.css'>
<% css(); %>
<script type='text/javascript' src='tomato.js'></script>
<style type='text/css'>
#ul-grid .co2 {
  text-align: center;
}
textarea {
  width: 98%;
  height: 10em;
}
</style>
<script type='text/javascript' src='interfaces.js'></script>
<script type='text/javascript'>
//	<% nvram("lan_ipaddr,lan_netmask,pptpd_enable,pptpd_remoteip,pptpd_forcemppe,pptpd_broadcast,pptpd_users,pptpd_dns1,pptpd_dns2,pptpd_wins1,pptpd_wins2,pptpd_mtu,pptpd_mru,pptpd_custom");%>

if (nvram.pptpd_remoteip == '') nvram.pptpd_remoteip = '172.19.0.1-6';
if (nvram.pptpd_forcemppe == '') nvram.pptpd_forcemppe = '1';

var ul = new TomatoGrid();
ul.setup = function() {
	this.init('ul-grid', 'sort', 6, [
		{ type: 'text', maxlen: 32, size: 32 },
		{ type: 'text', maxlen: 32, size: 32 } ]);

	this.headerSet(['Użytkownik', 'Hasło']);

	var r = nvram.pptpd_users.split('>');
	for (var i = 0; i < r.length; ++i) {
		var l = r[i].split('<');
		if (l.length == 2)
			ul.insertData(-1, l);
	}

	ul.recolor();
	ul.showNewEditor();
	ul.resetNewEditor();
	ul.sort(0);
}

ul.exist = function(f, v) {
	var data = this.getAllData();
	for (var i = 0; i < data.length; ++i) {
		if (data[i][f] == v) return true;
	}
	return false;
}

ul.existUser = function(user) {
	return this.exist(0, user);
}

function v_pptpd_secret(e, quiet) {
	var s;
	if ((e = E(e)) == null) return 0;
	s = e.value.trim().replace(/\s+/g, '');
	if (s.length < 1) {
		ferror.set(e, "Pola Użytkownik i Hasło nie mogą być puste.", quiet);
		return 0;
	}
	if (s.length > 32) {
		ferror.set(e, "Maksymalna dozwolona ilość znaków to 32.", quiet);
		return 0;
	}
	if (s.search(/^[.a-zA-Z0-9_\- ]+$/) == -1) {
		ferror.set(e, "Tylko znaki \"A-Z 0-9 . - _\" są dozwolone.", quiet);
		return 0;
	}
	e.value = s;
	ferror.clear(e);
	return 1;
}

ul.verifyFields = function(row, quiet) {
	var f, s;
	f = fields.getAll(row);

	if (!v_pptpd_secret(f[0], quiet)) return 0;

	if (this.existUser(f[0].value)) {
		ferror.set(f[0], 'Taki użytkownik już istnieje', quiet);
		return 0;
	}

	if (!v_pptpd_secret(f[1], quiet)) return 0;

	return 1;
}

ul.dataToView = function(data) {
	return [data[0], '<center><small><i>Tajne</i></small></center>'];
}

function save() {
	if (ul.isEditing()) return;

	if ((E('_f_pptpd_enable').checked) && (!verifyFields(null, 0))) return;

	if ((E('_f_pptpd_enable').checked) && (ul.getDataCount() < 1)) {
		var e = E('footer-msg');
		e.innerHTML = 'Ostrzeżenie: conajmniej jeden użytkownik musi być zdefiniowany.';
		e.style.visibility = 'visible';
		setTimeout(
			function() {
				e.innerHTML = '';
				e.style.visibility = 'hidden';
			}, 5000);
		return;
	}

	ul.resetNewEditor();

	var fom = E('_fom');
	var uldata = ul.getAllData();

	var s = '';
	for (var i = 0; i < uldata.length; ++i) {
		s += uldata[i].join('<') + '>';
	}
	fom.pptpd_users.value = s;

	fom.pptpd_enable.value = E('_f_pptpd_enable').checked ? 1 : 0;

	var a = E('_f_pptpd_startip').value;
	var b = E('_f_pptpd_endip').value;
	if ((fixIP(a) != null) && (fixIP(b) != null)) {
		var c = b.split('.').splice(3, 1);
		fom.pptpd_remoteip.value = a + '-' + c;
	}

	if (fom.pptpd_dns1.value == '0.0.0.0') fom.pptpd_dns1.value = '';
	if (fom.pptpd_dns2.value == '0.0.0.0') fom.pptpd_dns2.value = '';
	if (fom.pptpd_wins1.value == '0.0.0.0') fom.pptpd_wins1.value = '';
	if (fom.pptpd_wins2.value == '0.0.0.0') fom.pptpd_wins2.value = '';

	form.submit(fom, 1);
}

function submit_complete() {
/* REMOVE-BEGIN */
//	reloadPage();
/* REMOVE-END */
	verifyFields(null, 1);
}

function verifyFields(focused, quiet) {
	var c = !E('_f_pptpd_enable').checked;
	E('_pptpd_dns1').disabled = c;
	E('_pptpd_dns2').disabled = c;
	E('_pptpd_wins1').disabled = c;
	E('_pptpd_wins2').disabled = c;
	E('_pptpd_mtu').disabled = c;
	E('_pptpd_mru').disabled = c;
	E('_pptpd_forcemppe').disabled = c;
	E('_pptpd_broadcast').disabled = c;
	E('_f_pptpd_startip').disabled = c;
	E('_f_pptpd_endip').disabled = c;
	E('_pptpd_custom').disabled = c;

	var a = E('_f_pptpd_startip');
/* REMOVE-BEGIN */
/*
	if ((a.value == '') || (a.value == '0.0.0.0')) {
		var l;
		var m = aton(nvram.lan_ipaddr) & aton(nvram.lan_netmask);
		var o = (m) ^ (~ aton(nvram.lan_netmask))
		var n = o - m;
		do {
			if (--n < 0) {
				a.value = '';
				return;
			}
			m++;
		} while (((l = fixIP(ntoa(m), 1)) == null) || (l == nvram.lan_ipaddr) );
		a.value = l;
	}
*/
/* REMOVE-END */
	var b = E('_f_pptpd_endip');
/* REMOVE-BEGIN */
/*
	if ((b.value == '') || (b.value == '0.0.0.0')) {
		var l;
		var m = aton(nvram.lan_ipaddr) & aton(nvram.lan_netmask);
		var o = (m) ^ (~ aton(nvram.lan_netmask));
		var n = o - m;
		do {
			if (--n < 0) {
				b.value = '';
				return;
			}
			o--;
		} while (((l = fixIP(ntoa(o), 1)) == null) || (l == nvram.lan_ipaddr) || (Math.abs((aton(a.value) - (aton(l)))) > 5) );
		b.value = l;
	}

	var net = getNetworkAddress(nvram.lan_ipaddr, nvram.lan_netmask);
	var brd = getBroadcastAddress(net, nvram.lan_netmask);

	if ((aton(a.value) >= aton(brd)) || (aton(a.value) <= aton(net))) {
		ferror.set(a, 'Błędny początkowy adres IP.', quiet);
		return 0;
	} else {
		ferror.clear(a);
	}

	if ((aton(b.value) >= aton(brd)) || (aton(b.value) <= aton(net))) {
		ferror.set(b, 'Błędny końcowy adres IP', quiet);
		return 0;
	} else {
		ferror.clear(b);
	}
*/
/* REMOVE-END */
	if (Math.abs((aton(a.value) - (aton(b.value)))) > 5) {
		ferror.set(a, 'Błędny zakres (maks. 6 adresów IP)', quiet);
		ferror.set(b, 'Błędny zakres (maks. 6 adresów IP)', quiet);
		elem.setInnerHTML('pptpd_count', '(?)');
		return 0;
	} else {
		ferror.clear(a);
		ferror.clear(b);
	}

	if (aton(a.value) > aton(b.value)) {
		var d = a.value;
		a.value = b.value;
		b.value = d;
	}

	elem.setInnerHTML('pptpd_count', '(' + ((aton(b.value) - aton(a.value)) + 1) + ')');
/* REMOVE-BEGIN */
// AB TODO - move to ul.onOk, onAdd,onDelete?
//	elem.setInnerHTML('user_count', '(total ' + (ul.getDataCount()) + ')');
/* REMOVE-END */
	if (!v_ipz('_pptpd_dns1', quiet)) return 0;
	if (!v_ipz('_pptpd_dns2', quiet)) return 0;
	if (!v_ipz('_pptpd_wins1', quiet)) return 0;
	if (!v_ipz('_pptpd_wins2', quiet)) return 0;
	if (!v_range('_pptpd_mtu', quiet, 576, 1500)) return 0;
	if (!v_range('_pptpd_mru', quiet, 576, 1500)) return 0;

	if (!v_ip('_f_pptpd_startip', quiet)) return 0;
	if (!v_ip('_f_pptpd_endip', quiet)) return 0;

	return 1;
}

function init() {
	var c;
	if (((c = cookie.get('vpn_pptpd_notes_vis')) != null) && (c == '1')) toggleVisibility("notes");
	if (((c = cookie.get('vpn_pptpd_settings_vis')) != null) && (c == '0')) toggleVisibility("settings");
	if (((c = cookie.get('vpn_pptpd_userlist_vis')) != null) && (c == '0')) toggleVisibility("userlist");

	if (nvram.pptpd_remoteip.indexOf('-') != -1) {
		var tmp = nvram.pptpd_remoteip.split('-');
		E('_f_pptpd_startip').value = tmp[0];
		E('_f_pptpd_endip').value = tmp[0].split('.').splice(0,3).join('.') + '.' + tmp[1];
	}

	ul.setup();

	verifyFields(null, 1);
}

function toggleVisibility(whichone) {
	if (E('sesdiv_' + whichone).style.display == '') {
		E('sesdiv_' + whichone).style.display = 'none';
		E('sesdiv_' + whichone + '_showhide').innerHTML = '(Pokaż)';
		cookie.set('vpn_pptpd_' + whichone + '_vis', 0);
	} else {
		E('sesdiv_' + whichone).style.display='';
		E('sesdiv_' + whichone + '_showhide').innerHTML = '(Ukryj)';
		cookie.set('vpn_pptpd_' + whichone + '_vis', 1);
	}
}

</script>
</head>
<body onload='init()'>
<form id='_fom' method='post' action='tomato.cgi'>
<table id='container' cellspacing=0>
<tr><td colspan=2 id='header'>
  <div class='title'>Tomato</div>
  <div class='version'>Wersja <% version(); %></div>
</td></tr>
<tr id='body'><td id='navi'><script type='text/javascript'>navi()</script></td>
<td id='content'>
<div id='ident'><% ident(); %></div>
<input type='hidden' name='_nextpage' value='vpn-pptpd.asp'>
<input type='hidden' name='_nextwait' value='5'>
<input type='hidden' name='_service' value='firewall-restart,pptpd-restart,dnsmasq-restart'>
<input type='hidden' name='pptpd_users'>
<input type='hidden' name='pptpd_enable'>
<input type='hidden' name='pptpd_remoteip'>

<div class='section-title'>Konfiguracja serwera PPTP<small><i><a href='javascript:toggleVisibility("settings");'><span id='sesdiv_settings_showhide'>(Ukryj)</span></a></i></small></div>
<div class='section' id='sesdiv_settings'>
<script type='text/javascript'>
createFieldTable('', [
	{ title: 'Włącz', name: 'f_pptpd_enable', type: 'checkbox', value: nvram.pptpd_enable == '1' },
	{ title: 'Lokalny adres IP/maska', text: (nvram.lan_ipaddr + ' / ' + nvram.lan_netmask) },
	{ title: 'Zakres zdalnych adresów IP', multi: [
		{ name: 'f_pptpd_startip', type: 'text', maxlen: 15, size: 17, value: nvram.dhcpd_startip, suffix: '&nbsp;-&nbsp;' },
		{ name: 'f_pptpd_endip', type: 'text', maxlen: 15, size: 17, value: nvram.dhcpd_endip, suffix: ' <i id="pptpd_count"></i>' }
	] },
	{ title: 'Tryb Broadcast Relay', name: 'pptpd_broadcast', type: 'select', options: [['disable','Wyłączony'], ['br0','z LAN do klientów VPN'], ['ppp','od klinetów VPN do LAN'], ['br0ppp','Oba']], value: nvram.pptpd_broadcast },
	{ title: 'Szyfrowanie', name: 'pptpd_forcemppe', type: 'select', options: [[0, 'Brak'], [1, 'MPPE-128']], value: nvram.pptpd_forcemppe },
	{ title: 'Serwery DNS', name: 'pptpd_dns1', type: 'text', maxlen: 15, size: 17, value: nvram.pptpd_dns1 },
	{ title: '', name: 'pptpd_dns2', type: 'text', maxlen: 15, size: 17, value: nvram.pptpd_dns2 },
	{ title: 'Serwery WINS', name: 'pptpd_wins1', type: 'text', maxlen: 15, size: 17, value: nvram.pptpd_wins1 },
	{ title: '', name: 'pptpd_wins2', type: 'text', maxlen: 15, size: 17, value: nvram.pptpd_wins2 },
	{ title: 'MTU', name: 'pptpd_mtu', type: 'text', maxlen: 4, size: 6, value: (nvram.pptpd_mtu ? nvram.pptpd_mtu : 1450)},
	{ title: 'MRU', name: 'pptpd_mru', type: 'text', maxlen: 4, size: 6, value: (nvram.pptpd_mru ? nvram.pptpd_mru : 1450)},
	{ title: '<a href="http://poptop.sourceforge.net/" target="_new">Poptop</a><br>Własna konfiguracja', name: 'pptpd_custom', type: 'textarea', value: nvram.pptpd_custom }

]);
</script>
</div>

<div class='section-title'>Lista użytkowników PPTP<small><i><a href='javascript:toggleVisibility("userlist");'><span id='sesdiv_userlist_showhide'>(Ukryj)</span></a></i></small></div>
<!-- REMOVE-BEGIN -->
<!-- <div class='section-title'>PPTP User List <small> <span id='user_count'></span> <i><a href='javascript:toggleVisibility("userlist");'><span id='sesdiv_userlist_showhide'>(Click here to hide)</span></a></i></small></div> -->
<!--REMOVE-END -->
<div class='section' id='sesdiv_userlist'>
  <table class='tomato-grid' cellspacing=1 id='ul-grid'></table>
</div>

<div class='section-title'>Notka <small><i><a href='javascript:toggleVisibility("notes");'><span id='sesdiv_notes_showhide'>(Pokaż)</span></a></i></small></div>
<div class='section' id='sesdiv_notes' style='display:none'>
<ul>
<li><b>Lokalny adres IP/maska</b> - Adres użyty jako lokalne zakończenie tunelów PPP pomiędzy serwerem a klinetami VPN.</li>
<li><b>Remote IP Address Range</b> - Zdalne adresy użyte do tworzenia połączeń PPP (maks. 6).</li>
<li><b>Broadcast Relay Mode</b> - Przekazywanie pakietów pomiędzy interfejsem LAN a klinetami VPN.</li>
<li><b>Enable Encryption</b> - Włączenie tej opcji zezwoli na używanie szyfrowanie tunelu ale może spowodować zmniejszenie przepustowośći tunelu.</li>
<li><b>DNS Servers</b> - Pozwala na ręcznie zdefiniowanie serwerów DNS (jeżeli niezdefiniowane, lokalne serwery routera będą używane przez klientów VPN).</li>
<li><b>WINS Servers</b> - Pozwala na ręcznie zdefiniowanie serwerów WINS dla klientów VPN, niż te zdefiniowane w <a href=basic-network.asp>Podstawowe/Sieć</a>.</li>
<li><b>MTU</b> - Maksymalny rozmiar pakietu, który może zostać wysłany bez jego fragmentacji.</li>
<li><b>MRU</b> - Maksymalny rozmiar pakietu, który może zostać odebrany bez jego fragmentacji.</li>
</ul>

<small>
<ul>
<li><b>Pozostałe uwagi:</b>
<ul>
<li>Staraj się unikać wszelkich konfliktów miedzy zakresem DHCP a klientami VPN.</li>
</ul>
</small>
</div>

<br>
<div style="float:right;text-align:right">
&raquo; <a href="vpn-pptp-online.asp">Aktywność PPTP</a>
</div>

</td></tr>
<tr><td id='footer' colspan=2>
 <span id='footer-msg'></span>
 <input type='button' value='Zapisz' id='save-button' onclick='save()'>
 <input type='button' value='Anuluj' id='cancel-button' onclick='javascript:reloadPage();'>
</td></tr>
</table>
</form>
</body>
</html>
