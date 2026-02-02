<jsp:useBean id="translationItemJspBean" scope="session" class="fr.paris.lutece.plugins.referencelist.web.TranslationItemJspBean" />
<% String strContent = translationItemJspBean.processController ( request , response ); %>

<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:include page="../../AdminHeader.jsp" />

<%= strContent %>

<%@ include file="../../AdminFooter.jsp" %>
