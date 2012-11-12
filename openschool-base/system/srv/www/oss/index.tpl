<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" dir="ltr">
<head>
<title>PORTAL PAGE</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link rel="stylesheet" type="text/css" href="index.css?v=20100506">


<script type="text/javascript" language="JavaScript">

function info(id) {
	var e = document.getElementById("intro");
	if (e) {
		e.style.display = "none";
	}

	var e = document.getElementById("intro");
	if (e) {
		e.style.display = "none";
	}

for(i=1; i<9;i++){
	eid="info"+i;

	var e = document.getElementById(eid);
	if (e) {
		e.style.display = "none";
	}
}

var ee = document.getElementById("info"+id);
if (ee) {
	ee.style.display = "block";
}
}

function goto(url){
document.location.href=url;
}
</script>

</head>
<body>

<div id="header"  %HEADER_STYLE%>
	<div id="content" align="center">
	<table height="100%">
		<tr>
		<td>
			<img src="img/%LOGO%">
		</td>
		<td>
			<h1>%SNAME%</h1>
			<h2>%SDESCR%</h2>
		</td>
		</tr>
	</table>
	</div>
</div>

<div id="body">
<div id="content">
<div id="apps">

<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">
	<div class="box" onmouseover="info(1);"  onclick="goto('%URL1%');">
	<div class="app widget" >
		<span></span>
		<img src="img/%LOGO1%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	
	
	
<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box" onmouseover="info(2);"  onclick="goto('%URL2%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO2%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	
	
<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box mr" onmouseover="info(3);"  onclick="goto('%URL3%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO3%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	

<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">
	<div class="box mr" onmouseover="info(4);"  onclick="goto('%URL4%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO4%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	

<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box mr">
	<div class="app info">
			<div id="intro">
				Bewegen Sie die Maus über die Logos für weitere Infos<br></br>
				Move the mouse over the logos for additional informations
			</div>
	
			<div id="info1">
				<h1>%NAME1%</h1>
				%DESCRIPTION1%
			</div>
			<div id="info2">
				<h1>%NAME2%</h1>
				%DESCRIPTION2%
			</div>
			<div id="info3">
				<h1>%NAME3%</h1>
				%DESCRIPTION3%
			</div>
			<div id="info4">
				<h1>%NAME4%</h1>
				%DESCRIPTION4%
			</div>
			<div id="info5">
				<h1>%NAME5%</h1>
				%DESCRIPTION5%
			</div>			
			<div id="info6">
				<h1>%NAME6%</h1>
				%DESCRIPTION6%
			</div>
			<div id="info7">
				<h1>%NAME7%</h1>
				%DESCRIPTION7%
			</div>
			<div id="info8">
				<h1>%NAME8%</h1>
				%DESCRIPTION8%
			</div>			
	</div>
	</div>
<div style="clear:both;"></div>
</div></div></div></div></div>	


<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box mr" onmouseover="info(5);"  onclick="goto('%URL5%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO5%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	
	
<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box mr" onmouseover="info(6);"  onclick="goto('%URL6%');">
    <div class="app widget">
    	<span></span>
		<img src="img/%LOGO6%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	
	
<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">	
	<div class="box mr" onmouseover="info(7);" onclick="goto('%URL7%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO7%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	

<div class="shadow5 mr"><div class="shadow4"><div class="shadow3"><div class="shadow2"><div class="shadow">		
	<div class="box mr" onmouseover="info(8);" onclick="goto('%URL8%');">
	<div class="app widget">
		<span></span>
		<img src="img/%LOGO8%"></img>
	</div>
	</div>
	<div style="clear:both;"></div>
</div></div></div></div></div>	

	
	<div style="clear:both;"></div>
</div>
</div>
</div>
</body>
</html>
