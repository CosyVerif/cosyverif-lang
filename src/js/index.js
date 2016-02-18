rootURL = "http://localhost:8080/server.php";

url = "";
username = "";
password = "";

function getServerURL()
{
  return rootURL;
}

function get(url, successFunction, errorFunction)
{

  var params = {type: 'GET', url: rootURL + url, dataType: 'json', success : successFunction, error : errorFunction };

  if (!isNullUser())
  {
    params["beforeSend"] =  function (request) {
                             request.setRequestHeader("Authorization", "Basic  "+ btoa(getUserLogin() + ":" + getUserPassword()) +"==");
                            };
  }
  jQuery.ajax(params);
}

function post(url, data, successFunction, errorFunction)
{

  var params = {type: 'POST', contentType: 'application/json', url: rootURL + url, dataType: 'json', data : data, success: successFunction, error: errorFunction};

  if (!isNullUser())
  {
    params["beforeSend"] =  function (request) {
                             request.setRequestHeader("Authorization", "Basic  "+ btoa(getUserLogin() + ":" + getUserPassword()) +"==");
                            };
  }
  jQuery.ajax(params);
}

function put(url, data, successFunction, errorFunction)
{
  var params = {type: 'PUT', contentType: 'application/json', url: rootURL + url, dataType: 'json', data : data, success: successFunction, error: errorFunction};

  if (!isNullUser())
  {
    params["beforeSend"] =  function (request) {
                             request.setRequestHeader("Authorization", "Basic  "+ btoa(getUserLogin() + ":" + getUserPassword()) +"==");
                            };
  }
  jQuery.ajax(params);
}

function del(url, successFunction, errorFunction)
{
  var params = {type: 'DELETE', url: rootURL + url, success: successFunction, error: errorFunction};

  if (!isNullUser())
  {
    params["beforeSend"] =  function (request) {
                             request.setRequestHeader("Authorization", "Basic  "+ btoa(getUserLogin() + ":" + getUserPassword()) +"==");
                            };
  }
  jQuery.ajax(params);
}

function loginClick()
{
  setUserLogin(document.getElementById("usernamePlaceHolder").value);
  setUserPassword(document.getElementById("passwordPlaceHolder").value);
  if(getUserLogin() == '' || getUserPassword() == '')
  {
    alertNotification("danger", "Username or password empty !");
    return;
  }
  function authSuccess(data)
  {
    function success(data)
    {
      setUserName(data.name);
      showLoginLogout();
    }
    function error()
    {
      setUserLogin("");
      setUserPassword("");
      alertNotification("danger", "Username or password incorrect !");
    }
    get('/users/'+ getUserLogin(), success, error);
  }
  function authError(jqXHR, textStatus, errorThrown)
  {
    setUserLogin("");
    setUserPassword("");
    alertNotification("danger", "Username or password incorrect !");
  }
  get('/users', authSuccess, authError); 
}

function logoutClick(){
    setUserLogin("");
    setUserPassword("");
    setUserName("");
    showLoginLogout();
    showSearch(false);
}

function setUserLogin(value){
    window.sessionStorage.setItem("userLogin", value);
}

function getUserLogin(){
    return window.sessionStorage.getItem("userLogin");
}

function setUserPassword(value){
    window.sessionStorage.setItem("userPassword", value);
}

function getUserPassword(){
    return window.sessionStorage.getItem("userPassword");
}

function setUserName(value){
    window.sessionStorage.setItem("userName", value);
}

function getUserName(){
    return window.sessionStorage.getItem("userName");
}

function setCurrentURL(value){
  window.sessionStorage.setItem("currentURL", value);
}

function getCurrentURL(){
  return window.sessionStorage.getItem("currentURL");
}

function isNullUser()
{
  return (getUserLogin() == null || getUserLogin() == "");
}

function showLoginLogout()
{
  if(!isNullUser())
  {
    // User is loged in
    document.getElementById("btnLogin").style.display = 'none';
    document.getElementById("btnSignUp").style.display = 'none';
    document.getElementById("usernamePlaceHolder").style.display = 'none';
    document.getElementById("passwordPlaceHolder").style.display = 'none';
    document.getElementById("btnLogoff").style.display = 'inline';
    document.getElementById("usernameLabel").style.display = 'inline';
    document.getElementById("usernameLogo").style.display = 'inline';
    document.getElementById("usernameLabel").innerHTML = ' ' + getUserName();
    $("#userLogin").attr("onClick","showUser('/users/"+getUserLogin()+"')");
    showSearch(true);
  } 
  else 
  {
    // User NOT is loged in
    document.getElementById("btnLogin").style.display = 'inline';
    document.getElementById("btnSignUp").style.display = 'inline';
    document.getElementById("usernamePlaceHolder").style.display = 'inline';
    document.getElementById("passwordPlaceHolder").style.display = 'inline';
    document.getElementById("btnLogoff").style.display = 'none';
    document.getElementById("usernameLabel").style.display = 'none';
    document.getElementById("usernameLogo").style.display = 'none';
    showSearch(false);
  }
}

function showError(code, text, message)
{
  if (code == '200')
  {
    alertNotification("success", text +" : "+ message);
  }
  else if (code == '201')
  {
    alertNotification("success", text +" : "+ message);
  }
  else if (code == '204')
  {
    alertNotification("success", text +" : "+ message);
  }
  else if (code == '400')
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == '401')
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 403)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 404)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 409)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 410)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 422)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else if (code == 500)
  {
    alertNotification("danger", text +" : "+ message);
  }
  else
  {
    alert(text);
    alertNotification("danger", "Fatal error !");
  }
}

function alertNotification(type, data)
{
  var classVar = "alert alert-info";
  if (type == "success")
  {
    classVar = "alert alert-success";
  }
  else if (type == "info")
  {
    classVar = "alert alert-info";
  }
  else if (type == "warning")
  {
    classVar = "alert alert-warning";
  }
  else if (type == "danger")
  {
    classVar = "alert alert-danger";
  }

  classVar += " alert-dismissible";

  $("#alert").html('<div class="'+ classVar +'" role="alert"><button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>'+ data +'</div>');
}

function loadTemplate(templateName, container, is_append, data)
{
  var source = $("#" + templateName).html();
  var template = Handlebars.compile(source);
  if (is_append)
    $("#"+container).append(template(data));
  else
    $("#"+container).html(template(data));
}
