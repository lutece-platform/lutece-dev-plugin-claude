<%@ page contentType="text/plain; charset=UTF-8" %><%@ page import="org.eclipse.microprofile.config.Config, org.eclipse.microprofile.config.ConfigProvider, java.util.TreeSet" %><%--
  Bench probe, never shipped by a site: prints the configuration the running application resolves, one key=value per
  line, for site_check.py config --against. Copied into the assembled war by the bench with @@TOKEN@@ replaced by a
  random value; a request without that token gets nothing. Values of keys that look like secrets are masked.
--%><%
    if ( !"@@TOKEN@@".equals( request.getParameter( "token" ) ) )
    {
        response.setStatus( 404 );
        return;
    }
    Config mpConfig = ConfigProvider.getConfig( );
    TreeSet<String> names = new TreeSet<>( );
    for ( String name : mpConfig.getPropertyNames( ) )
    {
        names.add( name.startsWith( "%" ) && name.indexOf( '.' ) > 0 ? name.substring( name.indexOf( '.' ) + 1 ) : name );
    }
    java.util.regex.Pattern secret = java.util.regex.Pattern.compile( "(?i)(passw(or)?d|pwd|secret|token|credential|apikey|api[_.-]key|privatekey)" );
    StringBuilder sb = new StringBuilder( );
    for ( String name : names )
    {
        String value = mpConfig.getOptionalValue( name, String.class ).orElse( "" );
        if ( secret.matcher( name ).find( ) && !value.isEmpty( ) )
        {
            value = "*****";
        }
        sb.append( name.replace( "=", "\\=" ).replace( ":", "\\:" ) ).append( '=' ).append( value.replace( "\\", "\\\\" ).replace( "\n", "\\n" ).replace( "\r", "\\r" ) ).append( '\n' );
    }
    out.print( sb );
%>
