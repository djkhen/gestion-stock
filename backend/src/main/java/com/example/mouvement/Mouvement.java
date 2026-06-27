package com.example.mouvement;

import com.example.Article;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.*;


import java.time.LocalDateTime;

@Entity
public class Mouvement extends PanacheEntity {

	/**
	 * Le produit concerné par ce mouvement.
	 * @ManyToOne : plusieurs mouvements peuvent référencer le même produit.
	 * optional = false  ->  un mouvement DOIT avoir un produit (colonne NOT NULL).
	 */
	@ManyToOne(optional = false)
	public Article  article;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false)
	public TypeMouvement type;     // ENTREE, SORTIE, AJUSTEMENT

	@Column(nullable = false)
	public int quantite;           // toujours positive

	@Column(nullable = false)

	public LocalDateTime date;

	public String motif;           // "réception", "casse", "inventaire"...

	@PrePersist
	public void avantInsertion() {
		if (date == null) {
			date = LocalDateTime.now();
		}
	}
}
