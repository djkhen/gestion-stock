import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProduitService } from './produit.service';
import { Produit } from './produit.model';

@Component({
  selector: 'app-root',
  imports: [CommonModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent implements OnInit {
  produits: Produit[] = [];
  erreur = '';
  chargement = false;

  // Modèle lié au formulaire d'ajout
  nouveau: Produit = { nom: '', description: '', prix: 0 };

  constructor(private produitService: ProduitService) {}

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement = true;
    this.erreur = '';
    this.produitService.liste().subscribe({
      next: (data) => { this.produits = data; this.chargement = false; },
      error: () => {
        this.erreur = "Impossible de joindre l'API. Le backend est-il démarré ?";
        this.chargement = false;
      }
    });
  }

  ajouter(): void {
    if (!this.nouveau.nom) { return; }
    this.produitService.creer(this.nouveau).subscribe({
      next: () => {
        this.nouveau = { nom: '', description: '', prix: 0 };
        this.charger();
      },
      error: () => this.erreur = "Erreur lors de la création du produit."
    });
  }

  supprimer(id?: number): void {
    if (id == null) { return; }
    this.produitService.supprimer(id).subscribe({
      next: () => this.charger(),
      error: () => this.erreur = "Erreur lors de la suppression."
    });
  }
}
