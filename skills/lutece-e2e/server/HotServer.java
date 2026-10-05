import com.sun.jdi.Bootstrap;
import com.sun.jdi.ReferenceType;
import com.sun.jdi.VirtualMachine;
import com.sun.jdi.connect.AttachingConnector;
import com.sun.jdi.connect.Connector;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import javax.tools.DiagnosticCollector;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileObject;
import javax.tools.StandardJavaFileManager;
import javax.tools.ToolProvider;

/**
 * Warm compiler and class redefiner for a running JVM.
 * Reads lines of changed .java paths on stdin (one batch per line, space separated), compiles them against the
 * classpath, redefines the loaded classes through one persistent JDWP connection, and answers one line per batch:
 * OK n ms | COMPILE_ERROR msg | RESTART reason.
 * Usage: java HotServer.java host:port classpath outDir
 */
public class HotServer
{
    private static VirtualMachine _vm;

    /**
     * Serves batches until stdin closes.
     *
     * @param args host:port, the classpath, the output directory for compiled classes
     * @throws Exception on an unrecoverable I/O failure
     */
    public static void main( String[] args ) throws Exception
    {
        String target = args[0];
        String classpath = args[1];
        Path out = Path.of( args[2] );
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler( );
        StandardJavaFileManager files = compiler.getStandardFileManager( null, null, null );
        BufferedReader in = new BufferedReader( new InputStreamReader( System.in ) );
        System.out.println( "READY" );
        String line;
        while ( ( line = in.readLine( ) ) != null )
        {
            long start = System.nanoTime( );
            String[] sources = line.trim( ).split( "\\s+" );
            Path batch = out.resolve( "b" + start );
            Files.createDirectories( batch );
            DiagnosticCollector<JavaFileObject> diags = new DiagnosticCollector<>( );
            Iterable<? extends JavaFileObject> units = files.getJavaFileObjects( sources );
            boolean ok = compiler.getTask( null, files, diags,
                    List.of( "-nowarn", "-proc:none", "-g", "-cp", classpath, "-d", batch.toString( ) ), null, units ).call( );
            if ( !ok )
            {
                String msg = diags.getDiagnostics( ).isEmpty( ) ? "unknown" : diags.getDiagnostics( ).get( 0 ).toString( ).replace( '\n', ' ' );
                System.out.println( "COMPILE_ERROR " + msg );
                continue;
            }
            long compiled = System.nanoTime( );
            try
            {
                int n = redefine( target, batch );
                System.out.printf( "OK %d class(es) compile %d ms redefine %d ms%n", n, ( compiled - start ) / 1_000_000,
                        ( System.nanoTime( ) - compiled ) / 1_000_000 );
            }
            catch( UnsupportedOperationException e )
            {
                System.out.println( "RESTART structural change: " + e.getMessage( ) );
            }
            catch( Exception e )
            {
                _vm = null;
                System.out.println( "RESTART " + e.getClass( ).getSimpleName( ) + ": " + e.getMessage( ) );
            }
        }
    }

    /**
     * Redefines every class of a compiled batch that the JVM has loaded.
     *
     * @param target host:port of the JDWP agent
     * @param batch directory of the compiled classes
     * @return the number of redefined classes
     * @throws Exception when the JVM refuses
     */
    private static int redefine( String target, Path batch ) throws Exception
    {
        VirtualMachine vm = vm( target );
        Map<ReferenceType, byte[]> changes = new HashMap<>( );
        List<String> unknown = new ArrayList<>( );
        try ( Stream<Path> walk = Files.walk( batch ) )
        {
            for ( Path f : walk.filter( p -> p.toString( ).endsWith( ".class" ) ).toList( ) )
            {
                String name = batch.relativize( f ).toString( ).replace( ".class", "" ).replace( '/', '.' );
                List<ReferenceType> loaded = vm.classesByName( name );
                if ( loaded.isEmpty( ) )
                {
                    unknown.add( name );
                }
                byte[] bytes = Files.readAllBytes( f );
                loaded.forEach( t -> changes.put( t, bytes ) );
            }
        }
        if ( !unknown.isEmpty( ) && changes.isEmpty( ) && unknown.stream( ).anyMatch( n -> !n.contains( "$" ) ) )
        {
            throw new UnsupportedOperationException( "class not loaded yet: " + unknown );
        }
        vm.redefineClasses( changes );
        return changes.size( );
    }

    /**
     * Returns the persistent JDWP connection, attaching on first use or after a failure.
     *
     * @param target host:port
     * @return the connected virtual machine
     * @throws Exception when attaching fails
     */
    private static VirtualMachine vm( String target ) throws Exception
    {
        if ( _vm == null )
        {
            String[] hp = target.split( ":" );
            AttachingConnector socket = Bootstrap.virtualMachineManager( ).attachingConnectors( ).stream( )
                    .filter( c -> c.transport( ).name( ).equals( "dt_socket" ) ).findFirst( ).orElseThrow( );
            Map<String, Connector.Argument> params = socket.defaultArguments( );
            params.get( "hostname" ).setValue( hp[0] );
            params.get( "port" ).setValue( hp[1] );
            _vm = socket.attach( params );
        }
        return _vm;
    }
}
