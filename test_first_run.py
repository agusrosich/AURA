"""Script de prueba para verificar que first_run_setup funciona correctamente."""

import sys
import os

# Asegurar que podemos importar los módulos locales
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_import():
    """Prueba que el módulo se puede importar."""
    print("Probando importación de first_run_setup...")
    try:
        from first_run_setup import check_first_run, FirstRunSetupWindow
        print("✓ Importación exitosa")
        return True
    except Exception as e:
        print(f"✗ Error en importación: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_check_first_run():
    """Prueba la función check_first_run."""
    print("\nProbando check_first_run()...")
    try:
        from first_run_setup import check_first_run
        result = check_first_run()
        print(f"✓ check_first_run() retornó: {result}")
        if result:
            print("  → Es la primera ejecución (modelos no encontrados)")
        else:
            print("  → No es la primera ejecución (modelos ya descargados)")
        return True
    except Exception as e:
        print(f"✗ Error en check_first_run: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_window_creation():
    """Prueba crear la ventana sin mostrarla."""
    print("\nProbando creación de ventana...")
    try:
        import tkinter as tk
        from first_run_setup import FirstRunSetupWindow

        # Crear una ventana de prueba
        window = FirstRunSetupWindow(parent=None)
        print("✓ Ventana creada exitosamente")

        # Cerrar inmediatamente
        window.window.destroy()
        print("✓ Ventana cerrada exitosamente")
        return True
    except Exception as e:
        print(f"✗ Error creando ventana: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_window_show():
    """Prueba mostrar la ventana completa (modo interactivo)."""
    print("\nProbando ventana completa (modo interactivo)...")
    print("Nota: Debes cerrar la ventana manualmente para continuar")

    try:
        from first_run_setup import FirstRunSetupWindow

        # Crear y mostrar ventana
        window = FirstRunSetupWindow(parent=None)
        result = window.show()

        print(f"✓ Ventana mostrada y cerrada. setup_completed={result}")
        return True
    except Exception as e:
        print(f"✗ Error mostrando ventana: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Ejecuta todas las pruebas."""
    print("=" * 70)
    print("PRUEBAS DE first_run_setup.py")
    print("=" * 70)

    results = []

    # Prueba 1: Importación
    results.append(("Importación", test_import()))

    if results[-1][1]:  # Solo continuar si la importación funcionó
        # Prueba 2: check_first_run
        results.append(("check_first_run", test_check_first_run()))

        # Prueba 3: Creación de ventana
        results.append(("Creación de ventana", test_window_creation()))

        # Prueba 4: Mostrar ventana (solo si el usuario lo solicita)
        print("\n" + "=" * 70)
        response = input("¿Quieres probar la ventana completa? (s/n): ")
        if response.lower() in ['s', 'si', 'y', 'yes']:
            results.append(("Ventana completa", test_window_show()))

    # Resumen
    print("\n" + "=" * 70)
    print("RESUMEN DE PRUEBAS")
    print("=" * 70)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = "✓ PASÓ" if result else "✗ FALLÓ"
        print(f"{status}: {name}")

    print(f"\nResultado: {passed}/{total} pruebas pasadas")

    if passed == total:
        print("\n✓ ¡Todas las pruebas pasaron!")
        return 0
    else:
        print("\n✗ Algunas pruebas fallaron")
        return 1

if __name__ == "__main__":
    sys.exit(main())
