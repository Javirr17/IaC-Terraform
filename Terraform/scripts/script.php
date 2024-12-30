<?php
$host = getenv('POSTGRES_HOST');
$port = '5432';
$dbname = 'user_db'; 
$user = 'my_user'; 
$password = 'user_pwd'; 

$connString = "host=$host port=$port dbname=$dbname user=$user password=$password";

$conn = pg_connect($connString);

if (!$conn) {
    die("Error: No se pudo conectar a la base de datos. " . pg_last_error());
}

$query = 'SELECT * FROM test_results'; 
$result = pg_query($conn, $query);

if (!$result) {
    die("Error en la consulta: " . pg_last_error());
}

// Mostrar resultados
while ($row = pg_fetch_assoc($result)) {
    echo "<pre>";
    print_r($row);
    echo "</pre>";
}

pg_free_result($result);
pg_close($conn);
?>
