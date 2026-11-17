# Servidor VoodooCombo

El despliegue lo realiza el equipo humano. No se ha creado ninguna VM ni activado servicios.

## Exportar

Instalar las plantillas de Godot 4.7.2 que coincidan con el motor. Desde la raíz:

```sh
godot --headless --path . --export-release "Windows"
godot --headless --path . --export-release "Servidor Linux ARM64"
godot --headless --path . --export-release "Servidor Linux x86_64"
```

Los presets dedicados eliminan contenido visual mediante Strip Visuals; el sonido se sintetiza solamente en el cliente. Se conservan los JSON de mapas. Referencia: [exportación dedicada Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_dedicated_servers.html).

## Oracle, sin coste

1. Revisar [Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) y las cuotas efectivas de la cuenta antes de crear nada. Elegir únicamente recursos marcados Always Free en la región principal. No activar upgrades ni recursos de pago. Si falta capacidad A1, esperar o usar el PC de clase.
2. Crear una VM Ubuntu Ampere A1 dentro de las cuotas disponibles, incluyendo disco y memoria. Descargar/proteger la clave SSH fuera del repositorio. Acceso SSH solo con clave y limitado a la IP del administrador.
3. En la Security List de la subred añadir entrada UDP, destino 7777. No hace falta TCP para jugar. Mantener HTTP 8080 cerrado a Internet; usar túnel SSH para la presentación.
4. Conectarse con SSH. Crear usuario y directorio:

```sh
sudo useradd --system --create-home --shell /usr/sbin/nologin godotserver
sudo install -d -o godotserver -g godotserver /opt/voodoocombo
sudo ufw allow from DIRECCION_ADMIN to any port 22 proto tcp
sudo ufw allow 7777/udp
```

Comprobar las reglas existentes de iptables/nftables de la imagen antes de habilitar UFW; conservar la sesión SSH y verificar una segunda conexión. La regla de OCI y la del sistema deben permitir ambas UDP 7777.

5. Copiar por SCP el ejecutable ARM64 y su PCK, si se exportó separado, a /opt/voodoocombo. Aplicar chmod +x al ejecutable y propietario godotserver.
6. Copiar tools/voodoocombo.service a /etc/systemd/system/ y ejecutar:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now voodoocombo
sudo journalctl -u voodoocombo -f
```

7. Introducir la IP pública en AJUSTES → Servidor → Oracle (se puede escribir ahí; GameConfig.ONLINE_HOST queda vacío hasta que exista una VM). Nunca guardar claves o direcciones privadas en Git.
8. Desde dos redes distintas, crear sala, unirse por código, completar partida y revancha; anotar ping, arena y ganador. Confirmar presupuesto 0 y cuotas antes y después. Oracle puede recuperar instancias inactivas.

## Respaldo local

Windows: tools/start-server.bat, usando el mismo cliente exportado. Linux: tools/start-server.sh, preset x86_64. Abrir UDP 7777 en el firewall solo para la red de clase. En clientes seleccionar Red local e introducir la dirección del PC, o Este PC para 127.0.0.1. No requiere Internet.

Prueba automática local: tools/test-network.ps1. GET /status y GET /results están en el puerto 8080; los resultados se guardan en user://matches. Con systemd, los datos quedan bajo /var/lib/voodoocombo.
